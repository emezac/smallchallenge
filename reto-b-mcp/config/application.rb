require 'bundler/setup'
require 'rails'
require 'action_controller/railtie'
require_relative '../lib/web_app'

module BankGateway
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = ENV.fetch('SECRET_KEY_BASE')
    config.hosts = [URI(ENV.fetch('PUBLIC_ORIGIN')).host]
    config.logger = Logger.new(File::NULL) # Never log URL bearer grants.
    config.action_dispatch.show_exceptions = :none
    config.consider_all_requests_local = false
    config.middleware.delete Rack::Runtime
    routes.append { mount Gateway::WebApp.from_env => '/' }
  end
end
