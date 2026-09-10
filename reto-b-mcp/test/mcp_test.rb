require_relative 'domain_test'
require_relative '../lib/mcp_server'

class McpTest < GatewayTestCase
  def rpc(method, params = {})
    JSON.parse(Gateway.server(@d).handle_json(JSON.generate(jsonrpc: '2.0', id: 1, method: method, params: params)))
  end

  def test_only_three_tools
    result = rpc('tools/list')
    assert_equal %w[get_card_status get_action_status propose_action].sort, result.fetch('result').fetch('tools').map { |x| x['name'] }.sort
  end

  def test_forbidden_tool_never_executes
    result = rpc('tools/call', name: 'confirm_action', arguments: {})
    assert result['error']
    assert_equal 'ACTIVE', @d.card[:status]
  end

  def test_valid_read
    result = rpc('tools/call', name: 'get_card_status', arguments: {})
    assert_includes result.to_json, 'ACTIVE'
    refute result['error']
  end
end
