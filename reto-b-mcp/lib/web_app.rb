require 'rack'
require 'cgi'
require 'fileutils'
require 'thread'
require_relative 'mcp_server'
require_relative 'authentication'
require_relative 'runtime'

module Gateway
  # Rack-mounted inside Rails; dependencies injected for HTTP contract tests.
  class WebApp
    HEADERS = {
      'cache-control' => 'no-store', 'referrer-policy' => 'strict-origin',
      'content-security-policy' => "default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
      'x-content-type-options' => 'nosniff'
    }.freeze

    def self.from_env
      origin = ENV.fetch('PUBLIC_ORIGIN')
      key = ENV.fetch('AUDIT_KEY')
      secret = ENV.fetch('SECRET_KEY_BASE')
      raise Invalid, 'independent strong secrets required' if secret.bytesize < 64 || secret == key
      domain = Runtime.domain
      issuer_configured = !ENV.fetch('OAUTH_ISSUER', '').empty?
      key_sources = [ENV['OAUTH_PUBLIC_KEY_FILE'], ENV['OAUTH_JWKS_FILE']].select { |s| s && !s.empty? }
      raise Invalid, 'complete OAuth configuration required' if issuer_configured != (key_sources.length == 1)
      auth = if issuer_configured
        key_options = ENV['OAUTH_JWKS_FILE'] && !ENV['OAUTH_JWKS_FILE'].empty? ?
          { jwks: File.read(ENV.fetch('OAUTH_JWKS_FILE')) } :
          { public_key: File.read(ENV.fetch('OAUTH_PUBLIC_KEY_FILE')) }
        Authentication.new(issuer: ENV.fetch('OAUTH_ISSUER'), audience: origin.delete_suffix('/') + '/mcp',
          **key_options,
          revoked_ids: ENV.fetch('OAUTH_REVOKED_JTIS', '').split(','))
      else
        ->(_request) { false }
      end
      new(domain: domain, origin: origin, authenticate: auth)
    end

    def initialize(domain:, origin:, authenticate:)
      @domain, @origin, @authenticate = domain, origin, authenticate
      @mutex = Mutex.new
      @rate_mutex = Mutex.new
      @window, @requests = Process.clock_gettime(Process::CLOCK_MONOTONIC), 0
      @transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        Gateway.server(domain), stateless: true, enable_json_response: true,
        allowed_hosts: [URI(origin).host], allowed_origins: [origin], max_request_bytes: 16_384
      )
    end

    def response(code, body, extra = {})
      [code, HEADERS.merge('content-type' => 'text/html; charset=utf-8').merge(extra), [body]]
    end

    def call(env)
      request = Rack::Request.new(env)
      return response(403, 'Host not allowed') unless request.host == URI(@origin).host
      return response(400, 'HTTPS required') unless request.scheme == 'https'
      return response(200, 'ok') if request.get? && request.path == '/health/live'
      return response(429, 'Retry later', 'retry-after' => '60') unless within_rate_limit?
      if request.get? && request.path == '/.well-known/oauth-protected-resource'
        return response(503, 'OAuth configuration pending') unless @authenticate.respond_to?(:metadata)
        return response(200, JSON.generate(@authenticate.metadata), 'content-type' => 'application/json')
      end
      if request.path == '/mcp'
        challenge = %(Bearer resource_metadata="#{@origin}/.well-known/oauth-protected-resource", scope="bank:actions")
        return response(401, 'Authentication required', 'www-authenticate' => challenge) unless @authenticate.call(request)
        return @mutex.synchronize { @transport.call(env) }
      end
      @mutex.synchronize { web(request) }
    rescue Invalid
      response(422, 'Invalid request')
    rescue Conflict
      response(409, 'Link, session or action is unavailable. No operation was performed.')
    rescue Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError
      response(400, 'Invalid parameters')
    rescue SQLite3::BusyException
      response(503, 'Temporarily busy', 'retry-after' => '1')
    rescue StandardError => error
      if ENV['SAFE_AUTH_LOG'] == '1'
        location = error.backtrace_locations&.first
        warn JSON.generate(event: 'gateway_internal_error', error_class: error.class.name,
          file: location ? File.basename(location.path) : 'unknown', line: location&.lineno)
      end
      response(500, 'Internal error; check the action status before retrying')
    end

    # Single-demo global bound; edge rate limiting remains necessary for deployment.
    def within_rate_limit?
      @rate_mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @window, @requests = now, 0 if now - @window >= 60
        @requests += 1
        @requests <= 120
      end
    end

    def web(request)
      if request.get? && (match = %r{\A/c/([A-Za-z0-9_-]{43})\z}.match(request.path))
        grant = @domain.exchange(match[1])
        headers = {}
        # The confirmation begins as a top-level navigation from AIFindr to this
        # separate HTTPS origin. Lax permits the redirect to carry this
        # short-lived, action-scoped cookie; the state-changing POST remains
        # protected by CSRF plus Origin/Fetch-Metadata validation.
        { '__Host-confirm_session' => grant[:session], '__Host-confirm_csrf' => grant[:csrf] }.each do |name, value|
          Rack::Utils.set_cookie_header!(headers, name, value: value, path: '/', secure: true, httponly: true, same_site: :lax, max_age: 900)
        end
        return response(303, '', headers.merge('location' => "/actions/#{grant[:action_alias]}"))
      end
      match = %r{\A/actions/(act_[a-f0-9]{32})(?:/(confirm|reject|status))?\z}.match(request.path)
      return response(404, 'Not found') unless match
      id, operation = match.captures
      @domain.expire_pending if request.get?
      session = request.cookies.fetch('__Host-confirm_session', '')
      state = @domain.session_status(id, session)
      if request.get? && (operation.nil? || operation == 'status')
        if operation == 'status'
          return response(200, JSON.generate(state), 'content-type' => 'application/json')
        end
        csrf = CGI.escapeHTML(request.cookies.fetch('__Host-confirm_csrf', ''))
        buttons = if state[:status] == 'PENDING_CONFIRMATION'
          %w[confirm reject].map do |choice|
            "<form method='post' action='/actions/#{id}/#{choice}'><input type='hidden' name='csrf' value='#{csrf}'><button>#{choice == 'confirm' ? 'Confirmar bloqueo simulado' : 'Rechazar'}</button></form>"
          end.join
        else
          ''
        end
        return response(200, "<!doctype html><html lang='es'><meta charset='utf-8'><title>Confirmación de acción</title><main><h1>Bloqueo simulado</h1><p>Tarjeta demo terminada en 4242. No afecta una cuenta bancaria real.</p><p>Estado: #{state[:status]}</p>#{buttons}<a href='/actions/#{id}'>Actualizar estado</a></main></html>")
      end
      return response(405, 'Method not allowed') unless request.post? && %w[confirm reject].include?(operation)
      return response(403, 'Invalid origin') unless same_origin_form?(request)
      return response(415, 'Form required') unless request.media_type == 'application/x-www-form-urlencoded'
      input = request.body
      input.rewind
      body = input.read(4097).to_s
      return response(413, 'Request too large') if body.bytesize > 4096
      params = Rack::Utils.parse_query(body)
      return response(422, 'Invalid form') unless params.keys == ['csrf']
      result = @domain.decide(id: id, session: session, csrf: params['csrf'], decision: operation)
      response(operation == 'confirm' ? 202 : 200, "<p>#{result[:status]}</p><a href='/actions/#{id}'>Consultar estado</a>")
    end

    # Modern browsers normally send Origin for form POSTs, but some privacy or
    # tunnel interstitial flows omit it. In that case require Fetch Metadata's
    # explicit same-origin signal; never accept null, mismatched or cross-site
    # origins. The action-scoped session and synchronizer token are still
    # validated by Domain#decide.
    def same_origin_form?(request)
      origin = request.get_header('HTTP_ORIGIN')
      fetch_site = request.get_header('HTTP_SEC_FETCH_SITE')
      if ENV['SAFE_AUTH_LOG'] == '1'
        origin_state = if origin.nil? || origin.empty?
          'missing'
        elsif origin == @origin
          'match'
        elsif origin == 'null'
          'null'
        else
          'mismatch'
        end
        fetch_state = %w[same-origin same-site cross-site none].include?(fetch_site) ? fetch_site : (fetch_site ? 'other' : 'missing')
        warn JSON.generate(event: 'confirmation_request_context', origin: origin_state, fetch_site: fetch_state)
      end
      return false if fetch_site && fetch_site != 'same-origin'
      return true if origin == @origin

      (origin.nil? || origin.empty?) && fetch_site == 'same-origin'
    end
  end
end
