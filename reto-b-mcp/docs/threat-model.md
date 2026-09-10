# Threat model and remaining boundaries

Assets: simulated card state, confirmation capability, OAuth access, audit key and audit sequence.

| Threat | Implemented control | Evidence |
|---|---|---|
| Model invents confirmation tool/argument | Exact tool registry and closed input schemas; domain confirmation only through session/CSRF | MCP + hardening tests |
| Attacker reads another session | Random 256-bit session, hashed storage, action-bound query | Domain + web tests |
| Link leaked/replayed | 300-second grant, hash only, atomic consumption, 303, no-store/no-referrer | Domain + web tests |
| Cross-site confirmation | Exact Origin, Fetch Metadata, CSRF and action-scoped `SameSite=Lax` cookies | Web tests |
| Concurrent proposal/confirmation | BEGIN IMMEDIATE, unique active index and state checks | Persistence + hardening tests |
| Repeated worker execution | Durable confirmed row, unique effect, atomic local transaction | Persistence tests |
| Audit row changed | HMAC/hash chain and monotonic sequence, versioned key IDs | Tampering + rotation tests |
| Wrong access token | RS256 pinned key, issuer/audience/expiry/nbf/scope/jti and denylist | Authentication tests |
| Excess requests | Local 120/min global cap; SDK 16 KiB MCP body cap; 4 KiB web form cap | Configuration; edge tests pending |

Known limits: a compromised process with audit keys can forge logs. Tail truncation needs an externally retained checkpoint. A copied confirmation URL can be redeemed by its bearer; it is not verified banking identity. A link scanner may consume the grant; it cannot approve the action. Sessions for different browser tabs share the same cookie names; opening a new action invalidates access to the old tab through that browser cookie jar. Fixed demo principal is not tenant isolation. Error responses are sanitized; security-event logging and external monitoring need further work.

Application logs are disabled; deployment must redact proxy paths /c/* and never log Authorization or cookies. Forwarded headers must come only from the trusted TLS proxy. The upstream listener must remain private. JWT key/denylist refresh currently requires restart. Global rate limiting can cause shared-denial pressure and is not a substitute for per-client edge limits.

The simulated Core is local and transactional. Fault injection exercises observed state handling, not a proof of recovery from a remote bank API or arbitrary process crashes.
