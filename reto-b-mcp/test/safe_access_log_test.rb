require 'minitest/autorun'
require 'stringio'
require_relative '../lib/safe_access_log'

class SafeAccessLogTest < Minitest::Test
  def test_logs_protocol_path_without_headers_or_body
    output = StringIO.new
    app = Gateway::SafeAccessLog.new(->(_env) { [401, {}, ['no']] }, output: output)
    app.call('REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/mcp',
      'HTTP_AUTHORIZATION' => 'Bearer secret-token', 'rack.input' => StringIO.new('secret-body'))
    record = JSON.parse(output.string)
    assert_equal '/mcp', record.fetch('path')
    assert_equal 401, record.fetch('status')
    refute_includes output.string, 'secret-token'
    refute_includes output.string, 'secret-body'
  end

  def test_redacts_confirmation_grant_path
    output = StringIO.new
    app = Gateway::SafeAccessLog.new(->(_env) { [200, {}, ['ok']] }, output: output)
    app.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/c/sensitive-grant')
    assert_equal '[REDACTED]', JSON.parse(output.string).fetch('path')
    refute_includes output.string, 'sensitive-grant'
  end
end
