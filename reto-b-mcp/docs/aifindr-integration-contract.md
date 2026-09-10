# Contrato de integración con un host MCP

La evidencia integrada se registró con un host MCP, OAuth delegado y un origen HTTPS temporal. Este documento describe únicamente propiedades reproducibles, sin exponer proveedor, proyecto, tenant, callback o endpoint de esa sesión.

| Compuerta | Estado registrado | Condición verificable |
| --- | --- | --- |
| Workflow | Confirmado | El host conserva Agent Workflow; el comportamiento RAG legado no gobierna esta integración. |
| OAuth | Confirmado | Token RS256 delegado para PUBLIC_ORIGIN/mcp con el scope requerido. |
| Discovery | Confirmado | El host descubre exactamente las tres tools del gateway. |
| Allowlist | Confirmado | No se habilitan tools de confirmar o ejecutar. |
| Propuesta | Confirmado | PENDING_CONFIRMATION no cambia la tarjeta. |
| Confirmación | Confirmado | Ocurre sólo en la UI web, fuera de MCP. |
| Ejecución | Confirmado | Worker posterior entrega EXECUTED y tarjeta simulada BLOCKED. |
| Bypass conversacional | Confirmado | El agente no confirma ni ejecuta una petición de emergencia. |
| Refresh token automático | No ejecutado | Requiere contrato y configuración adicional del proveedor. |
| Hosting permanente y SLA | No ejecutado | Requiere infraestructura productiva. |

El prompt completo, IDs/versiones y evidencias de conversación se excluyen de
este repositorio. El texto exacto permanece publicado en Agent Workflow de
AIFindr y es la fuente autoritativa para un revisor autorizado. El contrato de
comportamiento relevante es que el agente sólo presenta el resultado de tools;
no interpreta una propuesta como ejecución ni puede omitir la página humana.
