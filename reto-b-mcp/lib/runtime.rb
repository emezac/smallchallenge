require 'fileutils'
require_relative 'domain'

module Gateway
  module Runtime
    module_function

    def domain
      path = ENV.fetch('DATABASE_PATH', 'storage/gateway.sqlite3')
      FileUtils.mkdir_p(File.dirname(path), mode: 0700)
      File.umask(0077)
      Domain.new(path: path, audit_key: ENV.fetch('AUDIT_KEY'), origin: ENV.fetch('PUBLIC_ORIGIN'),
        audit_key_id: ENV.fetch('AUDIT_KEY_ID', 'v1'),
        audit_previous_keys: JSON.parse(ENV.fetch('AUDIT_PREVIOUS_KEYS_JSON', '{}')))
    end
  end
end
