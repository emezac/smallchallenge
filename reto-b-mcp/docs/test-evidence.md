# Test evidence — 2026-09-09

Runtime: Ruby 3.4.1; locked Rails 8.1.3.1, MCP 1.3.0, SQLite3 2.9.6, JWT 3.2.0.

`bundle exec ruby bin/verify`: 26 tests, 113 assertions, zero failures/errors/skips.

Coverage: proposal deduplication including separate SQLite connections; link replay; expiry; forged session/CSRF; reject and repeat decisions; no execution before confirmation; worker restart and single effect; known failure; ambiguous result and reconciliation; audit tampering; exact three-tool registry; forbidden tool; authenticated HTTP discovery; cookie flags; Host/Origin validation; OAuth issuer/audience/signature/expiry/nbf/scope/revocation.

`bundle exec ruby test/rails_boot.rb`: Rails initializes, health returns 200, MCP without configured OAuth returns 401.

Integrated evidence: browser OAuth authorization round trip completed through Auth0; AIFindr displayed `Granted scopes: bank:actions`; public protected-resource metadata and unauthenticated rejection were verified; authenticated `List tools` completed over ngrok and returned exactly the three expected tools. The exact allowlist was saved and the MCP enabled. From Playground, all three tools ran successfully. Before confirmation, the proposal was `PENDING_CONFIRMATION`, the card remained `ACTIVE`, the human review page matched, and the worker had no job. The browser confirmation returned `CONFIRMED`; later page and MCP queries returned action `EXECUTED` and card `BLOCKED`. Sanitized gateway logs showed 200/202 exchanges without token or grant values.

The real browser run exposed and drove three controls that Rack-only testing could not validate on its own: `Referrer-Policy: strict-origin` through Chromium/ngrok, `SameSite=Lax` for the short-lived action-scoped cookies during the top-level AIFindr → ngrok redirect, and rewinding an upstream-consumed Rack body. `Lax` is deliberately limited to the initial navigation; the state-changing POST still requires the action session, CSRF token, exact Origin and Fetch Metadata. The final suite count includes the corresponding regressions.

Post-publication prompt evidence: the active Agent Workflow preserved the
clarification rule from Parte 1 and the MCP safety contract. A fresh
conversation rendered simulated `BLOCKED` status as user-facing text rather
than raw tool JSON; an emergency request to bypass the page was refused; an
isolated product-recommendation regression asked one minimum decision-factor
question without a product catalog or MCP call. The prompt text, identifiers,
digest and conversation artifacts are deliberately excluded from the public
manifest.

Reproducibility evidence: `bin/demo-reset` was executed only against a new temporary database and returned synthetic `card_demo` to `ACTIVE` while preserving audit history. Its domain test proves that reset is refused while an action is active and that terminal action history remains queryable. The integrated evidence database was not reset.

NOT_RUN: rejection and replay through the public browser flow; multi-turn agent evaluation; production reverse proxy/deployment. Expiration was observed publicly without mutation, while its detailed adversarial assertions remain local.

Additional checks: audit key rotation with historical signatures, expired page without confirmation form, two simultaneous confirmations (one accepted), extra MCP arguments rejected.

Design deviations tracked for review: Rack UI mounted inside Rails rather than generated Rails controllers/models; domain SQL transactions and confirmed rows as a durable queue rather than ActiveRecord/Solid Queue; random public action aliases rather than HMAC-derived aliases; no free-text reason; atomic local Core with test-only fault injection rather than a remote Core. Audit key rotation is implemented through versioned IDs and an explicit keyring. These are implemented choices, not evidence of the entire SDD being satisfied.
