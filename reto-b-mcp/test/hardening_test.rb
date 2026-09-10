require_relative 'domain_test'
require_relative '../lib/web_app'

class HardeningTest < GatewayTestCase
  def test_audit_rotation_preserves_old_signatures
    proposal
    rotated = Gateway::Domain.new(path: File.join(@dir, 'test.sqlite3'), audit_key: 'b' * 32,
      audit_key_id: 'v2', audit_previous_keys: { 'v1' => 'a' * 32 }, origin: 'https://example.test', clock: -> { @now })
    assert rotated.verify_audit
    @now += 301
    rotated.expire_pending
    assert rotated.verify_audit
    refute @d.verify_audit, 'old-only keyring must reject new signatures'
  ensure
    rotated&.close
  end

  def test_expired_page_has_no_confirm_form
    p = proposal
    app = Gateway::WebApp.new(domain: @d, origin: 'https://example.test', authenticate: ->(_) { false })
    http = Rack::MockRequest.new(app)
    result = http.get(p[:confirmation_url])
    cookies = Array(result.headers['set-cookie']).map { |c| c.split(';').first }.join('; ')
    @now += 301
    page = http.get('https://example.test' + result.headers['location'], 'HTTP_COOKIE' => cookies)
    assert_equal 200, page.status
    assert_includes page.body, 'EXPIRED'
    refute_includes page.body, '<form'
  end

  def test_confirmation_race
    p = proposal
    grant = @d.exchange(p[:confirmation_url].split('/').last)
    connections = 2.times.map do
      Gateway::Domain.new(path: File.join(@dir, 'test.sqlite3'), audit_key: 'a' * 32, origin: 'https://example.test', clock: -> { @now })
    end
    results = connections.map do |db|
      Thread.new do
        db.decide(id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'confirm')
        :accepted
      rescue Gateway::Conflict
        :rejected
      end
    end.map(&:value)
    assert_equal [:accepted, :rejected], results.sort
  ensure
    connections&.each(&:close)
  end

  def test_schema_rejects_extra_fields
    server = Gateway.server(@d)
    result = JSON.parse(server.handle_json(JSON.generate(jsonrpc: '2.0', id: 1, method: 'tools/call', params: {
      name: 'propose_action', arguments: { card_id: 'card_demo', action_type: 'CARD_BLOCK', reason_code: 'LOST_CARD', confirmed: true }
    })))
    assert result['error'] || result.dig('result', 'isError')
    assert_nil @d.work
    assert_equal 'ACTIVE', @d.card[:status]
  end
end
