# Reto B — Gateway MCP con confirmación humana

Gateway MCP para consultar una tarjeta simulada, proponer un bloqueo y consultar su estado. La propuesta no bloquea la tarjeta: la decisión ocurre en una UI web separada y un worker durable aplica el efecto simulado sólo después de confirmación humana.

## Flujo y seguridad

![Arquitectura end-to-end](docs/diagrams/mcp-end-to-end.svg)

![Máquina de estados](docs/diagrams/action-state-machine.svg)

- Catálogo MCP cerrado: get_card_status, propose_action y get_action_status.
- OAuth delegado RS256 con issuer, audience, expiración, nbf, sub, jti y scope validados.
- Grant opaco de un solo uso, sesión de acción, CSRF, Origin/Fetch Metadata y cookies Secure, HttpOnly, SameSite=Lax.
- Estado persistente, propuesta única activa, worker idempotente y auditoría HMAC encadenada.
- Ninguna tool MCP confirma, ejecuta, reintenta o reconstruye una URL de confirmación.

La [arquitectura](docs/architecture.md), la [secuencia](docs/sequence-diagram-v5.md) y el [modelo de amenazas](docs/threat-model.md) describen las fronteras y límites.

El contrato de comportamiento del agente se verificó contra el prompt publicado
en Agent Workflow. El texto exacto se mantiene alojado en AIFindr —su fuente
autoritativa— y puede ser inspeccionado allí por un revisor autorizado; no se
replica en este repositorio.

## Pruebas locales

Requisitos: Ruby 3.4.1 y Bundler.

    BUNDLE_PATH=vendor/bundle bundle install
    BUNDLE_PATH=vendor/bundle bundle exec ruby bin/verify

La evidencia registrada es 26 runs, 113 assertions, 0 failures, 0 errors y 0 skips. Incluye propuesta duplicada, replay, expiración, CSRF, carreras de confirmación, idempotencia del worker, auditoría, OAuth y el catálogo MCP. No requiere AIFindr, Auth0, ngrok ni .env.

Para leer el resumen de evidencia sin abrir JSON:

    ./bin/show-evidence

La configuración para una integración temporal con credenciales propias está en [docs/auth0-ngrok.md](docs/auth0-ngrok.md). Nunca copie una configuración privada, token, JWKS, URL temporal o grant en el repositorio.

## Evidencia y límites

La aceptación integrada registrada verificó OAuth delegado, discovery de las tres tools, propuesta sin efecto, confirmación humana, ejecución posterior del worker y consulta final. Consulte el [manifiesto público](evidence/manifest.json) y [test-evidence.md](docs/test-evidence.md).

No se afirma despliegue productivo, carga sostenida, refresh token automático, ni pruebas públicas de replay/rechazo del navegador. La evolución deliberada hacia producción está en [../ROADMAP_PRODUCCION.md](../ROADMAP_PRODUCCION.md).
