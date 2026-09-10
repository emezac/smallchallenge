# Deployment package (not deployed)

For the selected local test path, see [ngrok + Auth0 setup](auth0-ngrok.md). OAuth integration was verified with the dedicated development Auth0 tenant and AIFindr on 2026-09-09. Docker remains optional for this local acceptance path.

Dockerfile and compose.yaml build web and worker from the locked Ruby dependencies. There is no Docker runtime available in the current workspace; image build and compose launch remain NOT_RUN. The files are prepared for a Linux host, not proof of deployability.

1. Create a private .env with PUBLIC_ORIGIN, AUDIT_KEY, SECRET_KEY_BASE and OAuth configuration. Never reuse the assigned AIFindr API key as a gateway secret.
2. Prefer mounting a verified issuer JWKS snapshot under secrets/ and set OAUTH_JWKS_FILE=/app/secrets/issuer-jwks.json. OAUTH_PUBLIC_KEY_FILE remains a single-key fallback; configure exactly one. Configure a provider that issues the validated RS256 access-token profile for the audience PUBLIC_ORIGIN/mcp.
3. Build and start with `docker compose up --build -d`. The web port is published only on 127.0.0.1. A trusted TLS proxy on the host must route the chosen HTTPS origin to port 9292.
4. Verify private storage ownership and persistence; run `docker compose exec web bundle exec ruby bin/doctor` and `bin/verify-audit` through Ruby.
5. Test provider consent, protected-resource metadata, token refresh and exact audience with AIFindr before enabling tools. Token validation alone is not completion of OAuth integration.
6. Verify security headers, HTTPS forwarding, payload limits, latency and sanitized proxy logging at the actual edge. Then run browser confirmation end-to-end and preserve evidence.

Single web process + single worker only. Both use the shared SQLite volume. No automatic data reset, production data import or public authentication bypass is provided. Back up volume and retain old audit keys before rotating; update AUDIT_KEY_ID/AUDIT_KEY and AUDIT_PREVIOUS_KEYS_JSON on both processes, then restart.
