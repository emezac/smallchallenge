require 'bundler/setup'
require 'securerandom'
require 'tmpdir'
ENV['DATABASE_PATH'] = File.join(Dir.mktmpdir('gateway-rails-test-'), 'gateway.sqlite3')
ENV['SECRET_KEY_BASE'] = SecureRandom.hex(64)
ENV['AUDIT_KEY'] = SecureRandom.hex(32)
ENV['PUBLIC_ORIGIN'] = 'https://example.test'
ENV['RAILS_ENV'] = 'test'
require_relative '../config/application'
BankGateway::Application.initialize!
request = Rack::MockRequest.new(BankGateway::Application)
result = request.get('https://example.test/health/live', 'HTTP_HOST' => 'example.test')
abort "Rails boot check failed: #{result.status} #{result.body[0,1500]}" unless result.status == 200
result = request.post('https://example.test/mcp', 'HTTP_HOST' => 'example.test')
abort 'Unconfigured OAuth must deny MCP access' unless result.status == 401
puts 'Rails boot and deny-by-default checks passed.'
