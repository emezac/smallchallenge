require_relative 'config/application'
require_relative 'lib/safe_access_log'
BankGateway::Application.initialize!
use Gateway::SafeAccessLog if ENV['SAFE_ACCESS_LOG'] == '1'
run BankGateway::Application
