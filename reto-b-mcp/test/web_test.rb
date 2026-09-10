require_relative 'domain_test'
require_relative '../lib/web_app'

class WebTest < GatewayTestCase
  def setup
    super
    @app = Gateway::WebApp.new(domain: @d, origin: 'https://example.test', authenticate: ->(r) { r.get_header('HTTP_AUTHORIZATION') == 'Bearer test-only' })
    @http = Rack::MockRequest.new(@app)
  end

  def exchange_http
    p = proposal
    result = @http.get(p[:confirmation_url])
    assert_equal 303, result.status
    @cookies = Array(result.headers['set-cookie']).map { |c| c.split(';').first }.join('; ')
    @action = 'https://example.test' + result.headers['location']
    result
  end

  def test_http_confirmation
    exchange_http
    page = @http.get(@action, 'HTTP_COOKIE' => @cookies)
    assert_equal 200, page.status
    csrf = page.body[/name='csrf' value='([^']+)'/, 1]
    args = { 'HTTP_COOKIE' => @cookies, 'CONTENT_TYPE' => 'application/x-www-form-urlencoded', input: "csrf=#{csrf}" }
    assert_equal 403, @http.post(@action + '/confirm', **args).status
    assert_equal 403, @http.post(@action + '/confirm', **args, 'HTTP_ORIGIN' => 'https://evil.test').status
    assert_equal 202, @http.post(@action + '/confirm', **args, 'HTTP_ORIGIN' => 'https://example.test').status
    assert_equal 'ACTIVE', @d.card[:status]
    @d.work
    assert_equal 'BLOCKED', @d.card[:status]
    assert_equal 409, @http.post(@action + '/confirm', **args, 'HTTP_ORIGIN' => 'https://example.test').status
  end

  def test_http_confirmation_uses_fetch_metadata_when_origin_is_omitted
    exchange_http
    page = @http.get(@action, 'HTTP_COOKIE' => @cookies)
    csrf = page.body[/name='csrf' value='([^']+)'/, 1]
    args = { 'HTTP_COOKIE' => @cookies, 'CONTENT_TYPE' => 'application/x-www-form-urlencoded', input: "csrf=#{csrf}" }

    assert_equal 403, @http.post(@action + '/confirm', **args).status
    assert_equal 403, @http.post(@action + '/confirm', **args, 'HTTP_ORIGIN' => 'null', 'HTTP_SEC_FETCH_SITE' => 'same-origin').status
    assert_equal 403, @http.post(@action + '/confirm', **args, 'HTTP_ORIGIN' => 'https://example.test', 'HTTP_SEC_FETCH_SITE' => 'cross-site').status
    assert_equal 202, @http.post(@action + '/confirm', **args, 'HTTP_SEC_FETCH_SITE' => 'same-origin').status
  end

  def test_http_confirmation_rewinds_body_consumed_by_upstream_stack
    exchange_http
    page = @http.get(@action, 'HTTP_COOKIE' => @cookies)
    csrf = page.body[/name='csrf' value='([^']+)'/, 1]
    env = Rack::MockRequest.env_for(@action + '/confirm', method: 'POST', input: "csrf=#{csrf}",
      'HTTP_COOKIE' => @cookies, 'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      'HTTP_ORIGIN' => 'https://example.test')
    env.fetch('rack.input').read

    status, = @app.call(env)
    assert_equal 202, status
  end

  def test_mcp_auth_and_discovery
    message = JSON.generate(jsonrpc: '2.0', id: 1, method: 'tools/list')
    args = { input: message, 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json, text/event-stream' }
    assert_equal 401, @http.post('https://example.test/mcp', **args).status
    result = @http.post('https://example.test/mcp', **args, 'HTTP_AUTHORIZATION' => 'Bearer test-only')
    assert_equal 200, result.status, result.body
    assert_equal 3, JSON.parse(result.body).fetch('result').fetch('tools').size
  end

  def test_cookie_security_and_host
    result = exchange_http
    Array(result.headers['set-cookie']).each do |cookie|
      assert_match(/secure/i, cookie)
      assert_match(/httponly/i, cookie)
      assert_match(/samesite=lax/i, cookie)
    end
    assert_equal 'strict-origin', result.headers['referrer-policy']
    assert_equal 403, @http.get('https://evil.test/health/live').status
    assert_equal 400, @http.get('http://example.test/health/live').status
    assert_equal 409, @http.get(@action).status
  end
end
