# One process for the SQLite demo; deploy behind a trusted TLS reverse proxy.
workers 0
threads 1, 4
bind ENV.fetch('PUMA_BIND', 'tcp://127.0.0.1:9292')
