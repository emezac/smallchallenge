# Evolución hacia producción — fuera del alcance del reto

El gateway entregado demuestra un flujo seguro para datos simulados en un solo
nodo: OAuth delegado, tres tools MCP cerradas, confirmación humana web,
idempotencia y auditoría. Esta hoja de ruta no afirma que los elementos
siguientes estén implementados; describe la evolución necesaria antes de usar
la arquitectura con clientes, tarjetas o efectos reales.

## Prioridad 1 — identidad y perímetro

### Refresco controlado de JWKS

Hoy el gateway verifica RS256 contra un snapshot confiable cargado al arrancar.
En producción se debe obtener el JWKS exclusivamente desde el discovery HTTPS
del issuer previamente configurado, con caché de duración acotada, validación de
issuer y algoritmo, rotación atómica por `kid`, y telemetría para claves
próximas a expirar. Ante un `kid` desconocido se permite un único refresco
controlado; nunca se sigue una URL indicada por el token.

**Criterio de aceptación:** la rotación normal no interrumpe tráfico válido; un
issuer, algoritmo o URL no confiables siguen siendo rechazados.

### Rate limiting por identidad en el borde

El límite local por proceso es adecuado para la demo, pero no protege un
servicio distribuido. Un proxy o API gateway debe aplicar límites por cliente
OAuth, subject, IP y ruta, con cuotas independientes para `/mcp`, creación de
propuestas y confirmaciones. Los límites deben compartirse entre réplicas y
producir señales de abuso sin registrar bearer tokens, cookies ni grants.

**Criterio de aceptación:** un actor abusivo no degrada a otros; el throttling
no cambia ni ejecuta una acción.

## Prioridad 2 — auditoría y durabilidad

### Checkpoint de auditoría fuera de la base operativa

La cadena HMAC detecta alteraciones mientras sus claves y la base no estén
comprometidas conjuntamente. En producción se necesita anclar periódicamente un
checkpoint firmado —secuencia, hash final, key ID y timestamp— en un almacén
con retención independiente e inmutable. Las claves deben vivir en KMS/HSM con
rotación y acceso mínimo.

**Criterio de aceptación:** una reescritura o truncamiento local posterior al
checkpoint se detecta durante una verificación independiente.

### PostgreSQL y cola durable

SQLite y el worker local hacen visible la separación entre `CONFIRMED` y
`EXECUTED`, pero no ofrecen alta disponibilidad. La evolución sustituye la base
por PostgreSQL y usa un patrón transactional outbox con una cola durable. Los
workers necesitan leases, reintentos clasificados, DLQ, deduplicación por
`action_id` y reconciliación explícita de resultados ambiguos.

**Criterio de aceptación:** una caída entre confirmación y ejecución conserva
la intención y nunca crea un efecto duplicado.

## Prioridad 3 — aislamiento de clientes

### Multi-tenancy y autorización de recurso

La demo usa una identidad y tarjeta sintéticas. Para producción, cada request
debe resolver un principal autenticado y una pertenencia a tenant; cada tarjeta
y acción debe estar autorizada contra ese principal. Aplicar aislamiento por
schema o Row Level Security, IDs no adivinables, claves/auditoría con ámbito de
tenant y trazabilidad de decisiones administrativas.

**Criterio de aceptación:** ni una tool MCP, ni una URL de confirmación, ni un
trabajo interno permite leer o afectar recursos de otro tenant.

## Orden recomendado

1. Borde OAuth/JWKS y rate limiting distribuido.
2. Almacenamiento de auditoría externo y observabilidad con redacción.
3. PostgreSQL, outbox y workers con recuperación.
4. Multi-tenancy y pruebas de aislamiento.
5. Carga, recuperación ante desastre, pentest y despliegue permanente.

No se debe acelerar esta transición cambiando la regla central de seguridad:
el MCP expresa intención, una persona confirma fuera del canal MCP y un proceso
idempotente ejecuta sólo después de esa confirmación.
