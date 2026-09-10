# Mediciones y evidencia

## Automatización

| Medida | Resultado |
| --- | --- |
| Suite | 26 runs, 113 assertions |
| Fallos / errores / skips | 0 / 0 / 0 |
| Catálogo MCP | 3 tools exactas |
| Ejecuciones sin confirmación en tests | 0 |
| Efectos duplicados en tests | 0 |
| Auditoría | PASS |
| Doctor | DB PASS, audit PASS, OAuth local PASS, E2E PASS_RECORDED |

## Integración observada

| Compuerta | Resultado |
| --- | --- |
| OAuth Auth0 → AIFindr | PASS, `bank:actions` |
| Discovery / allowlist | PASS, 3/3 |
| Estado antes de confirmar | tarjeta ACTIVE; acción PENDING_CONFIRMATION |
| Confirmación browser | 202, CONFIRMED |
| Estado posterior del worker | acción EXECUTED; tarjeta BLOCKED |
| JSON crudo después del nuevo prompt | No observado en caso de estado |
| Bypass “emergencia” | Rechazado |
| Regresión de aclaración Parte 1 | Una pregunta mínima; sin catálogo ni MCP |

## Presupuestos y límites

- Request MCP limitado a 16 KiB por transporte; formulario limitado a 4096 bytes.
- Grant de propuesta: 300 segundos; sesión de lectura/decisión: 900 segundos.
- Rate limiter local: 120 requests por minuto por proceso; no sustituye control de borde.
- No se midieron p95/p99, throughput sostenido, costo LLM ni latencia de una topología productiva.
- No se ejecutó una carga pequeña pública ni un dataset multi-turn amplio; ambos permanecen `NOT_RUN`.

El resumen público de resultados y versiones está en `../evidence/manifest.json`.
No se incluyen tiempos inventados: los logs sanitizados usados en la sesión no
se vuelcan porque contienen secuencia operativa efímera y no aportan un
artefacto estable adicional. Los hashes que puedan identificar artefactos
privados también se excluyeron de esta copia.
