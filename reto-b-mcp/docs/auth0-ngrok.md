# Integración temporal mediante OAuth y túnel HTTPS

Este documento es una plantilla de reproducción. Los nombres, dominios, callbacks, IDs y secretos usados durante la evidencia se excluyeron del paquete público.

## Objetivo

Permitir que un host MCP alcance temporalmente un gateway local por HTTPS, se autorice mediante OAuth delegado y descubra exactamente las tres tools permitidas. El túnel aporta conectividad; no autoriza acciones ni sustituye el despliegue productivo.

## Configuración mínima

1. Cree un tenant OAuth propio y una API cuyo audience sea exactamente PUBLIC_ORIGIN/mcp.
2. Configure access tokens RS256 y un scope dedicado, por ejemplo bank:actions; asigne ese scope sólo al usuario de prueba.
3. Registre un cliente OAuth con Authorization Code + PKCE y una callback exacta proporcionada por el host. No use comodines ni publique el secreto.
4. Obtenga el JWKS sólo desde el discovery HTTPS del issuer configurado y guárdelo fuera de Git.
5. Inicie el gateway local y expóngalo con un túnel HTTPS sin inspección de tráfico. Configure el mismo origen en PUBLIC_ORIGIN, audience OAuth y endpoint MCP del host.

Una configuración de ejemplo privada se crea localmente con:

    bin/setup-local-env

El script deja valores no routables para PUBLIC_ORIGIN y vacía el issuer; deben sustituirse en el archivo .env, que no se entrega ni se versiona.

## Validación de aceptación

1. Sin token, /mcp debe responder 401 y anunciar metadata del recurso.
2. Con un token delegado válido, discovery debe devolver sólo get_card_status, propose_action y get_action_status.
3. propose_action debe dejar tarjeta ACTIVE y acción PENDING_CONFIRMATION.
4. La confirmación humana, en el origen HTTPS del gateway, debe producir CONFIRMED; sólo el worker puede llegar después a EXECUTED y BLOCKED.
5. No registre ni muestre Authorization, cookies, grants, URLs de confirmación, secretos ni capturas sin redactar.

Al finalizar, detenga túnel y procesos locales. La [guía de demo](demo-runbook.md) y el [modelo de amenazas](threat-model.md) detallan los controles aplicables.

