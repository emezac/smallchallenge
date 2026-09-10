require 'json'

module Gateway
  # Diagnostic logging that never records headers, query strings, bodies or
  # action/grant identifiers. Enable only while troubleshooting integration.
  class SafeAccessLog
    VISIBLE_PATHS = %w[/mcp /health/live /.well-known/oauth-protected-resource].freeze

    def initialize(app, output: $stderr)
      @app = app
      @output = output
    end

    def call(env)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, headers, body = @app.call(env)
      path = env.fetch('PATH_INFO', '')
      event = {
        event: 'http_request',
        method: env.fetch('REQUEST_METHOD', ''),
        path: VISIBLE_PATHS.include?(path) ? path : '[REDACTED]',
        status: status,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      }
      @output.puts(JSON.generate(event))
      [status, headers, body]
    end
  end
end
