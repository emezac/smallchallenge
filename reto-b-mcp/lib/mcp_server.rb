require 'mcp'
require_relative 'domain'

module Gateway
  def self.server(domain)
    definitions = [
      ['get_card_status', 'Read the single simulated card. Does not change it.', {}, [], ->(_args) { domain.card }],
      ['propose_action', 'Propose simulated card blocking. Never confirms or executes. Return the confirmation link unchanged when present.',
       { card_id: { type: 'string', enum: ['card_demo'] }, action_type: { type: 'string', enum: ['CARD_BLOCK'] }, reason_code: { type: 'string', enum: %w[LOST_CARD STOLEN_CARD SUSPECTED_FRAUD OTHER] } },
       %w[card_id action_type reason_code], ->(args) { domain.propose(**args) }],
      ['get_action_status', 'Read a proposal status. Only EXECUTED means the simulated blocking completed.',
       { action_alias: { type: 'string', pattern: '^act_[a-f0-9]{32}$' } }, ['action_alias'], ->(args) { domain.status(args.fetch(:action_alias)) }]
    ]
    tools = definitions.map do |name, description, properties, required, operation|
      Class.new(MCP::Tool) do
        tool_name name
        description description
        input_schema(type: 'object', properties: properties, required: required, additionalProperties: false)
        define_singleton_method(:call) do |**args|
          args.delete(:server_context)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(operation.call(args)) }])
        rescue Gateway::Invalid, Gateway::Conflict => error
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(error: error.message) }], is_error: true)
        end
      end
    end
    MCP::Server.new(name: 'bank-actions-demo', version: '0.1.0', tools: tools)
  end
end
