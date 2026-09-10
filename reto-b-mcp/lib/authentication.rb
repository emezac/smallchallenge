require 'jwt'
require 'json'
require 'openssl'
require 'uri'

module Gateway
  # Resource-server adapter for an external OAuth issuer. Keys are pinned from
  # deployment configuration, never fetched from a URL inside a client token.
  class Authentication
    attr_reader :issuer, :audience, :scope
    def initialize(issuer:, audience:, public_key: nil, jwks: nil, scope: 'bank:actions', revoked_ids: [])
      @issuer, @audience, @scope = issuer, audience, scope
      @revoked_ids = revoked_ids.freeze
      @safe_diagnostics = ENV['SAFE_AUTH_LOG'] == '1'
      [issuer, audience].each do |value|
        uri = URI(value)
        raise ArgumentError, 'HTTPS auth configuration required' unless uri.scheme == 'https' && uri.host && !uri.userinfo && !uri.query && !uri.fragment
      end
      raise ArgumentError, 'configure exactly one OAuth key source' unless [public_key, jwks].compact.length == 1
      if jwks
        @keys = load_jwks(jwks).freeze
      else
        @key = validate_public_key(OpenSSL::PKey::RSA.new(public_key))
      end
    end

    def call(request)
      header = request.get_header('HTTP_AUTHORIZATION').to_s
      return deny('authorization_header') unless header.start_with?('Bearer ') && header.bytesize <= 8192
      token = header.delete_prefix('Bearer ')
      key = verification_key(token)
      return deny('verification_key') unless key
      claims, = JWT.decode(token, key, true, algorithm: 'RS256',
        iss: issuer, verify_iss: true, aud: audience, verify_aud: true,
        verify_expiration: true, verify_not_before: true,
        required_claims: %w[iss aud exp sub jti])
      return deny('subject') unless claims['sub'].is_a?(String) && !claims['sub'].empty?
      return deny('expiration') unless claims['exp'].is_a?(Numeric) && claims['exp'] > Time.now.to_i
      return deny('token_id') unless claims['jti'].is_a?(String) && !@revoked_ids.include?(claims['jti'])
      return deny('scope') unless claims['scope'].is_a?(String) && claims['scope'].split.include?(scope)
      true
    rescue JWT::DecodeError, JWT::JWKError, JSON::ParserError, ArgumentError, TypeError => error
      deny(error.class.name)
    end

    def metadata
      { resource: audience, authorization_servers: [issuer], scopes_supported: [scope], bearer_methods_supported: ['header'] }
    end

    private

    def deny(reason)
      warn JSON.generate(event: 'oauth_denied', reason: reason) if @safe_diagnostics
      false
    end

    def validate_public_key(key)
      raise ArgumentError, 'RSA public key of at least 2048 bits required' if key.private? || key.n.num_bits < 2048
      key
    end

    def load_jwks(value)
      document = value.is_a?(String) ? JSON.parse(value) : value
      raise ArgumentError, 'invalid JWKS document' unless document.is_a?(Hash) && document['keys'].is_a?(Array)
      document['keys'].each_with_object({}) do |entry, keys|
        next unless entry.is_a?(Hash) && entry['kty'] == 'RSA'
        next if entry['use'] && entry['use'] != 'sig'
        next if entry['alg'] && entry['alg'] != 'RS256'
        kid = entry['kid']
        raise ArgumentError, 'JWKS signing key requires kid' unless kid.is_a?(String) && !kid.empty?
        raise ArgumentError, 'duplicate JWKS kid' if keys.key?(kid)
        keys[kid] = validate_public_key(JWT::JWK.import(entry).public_key)
      end.tap { |keys| raise ArgumentError, 'no acceptable JWKS signing keys' if keys.empty? }
    end

    def verification_key(token)
      return @key unless @keys
      _claims, header = JWT.decode(token, nil, false)
      kid = header['kid']
      kid.is_a?(String) ? @keys[kid] : nil
    end
  end
end
