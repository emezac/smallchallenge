# Control de publicación

Este directorio se regeneró como una copia segura de Parte 1.

## Incluido

- Resultado agregado before/after.
- Dataset sintético de ejemplo, rúbrica y evaluador.
- Diagramas de arquitectura/configuración y comparación.
- Declaración de uso de IA.

## Excluido

- .env, credenciales, API keys, tokens, cookies y configuraciones del Hub.
- Prompts completos, IDs y versiones de prompt.
- Conversaciones, transcripciones, resultados detallados y hashes de respuestas.
- Datasets privados, bases de datos, logs, capturas y contenido de KB.

El prompt exacto permanece disponible en Agent Workflow de AIFindr para revisores con acceso autorizado. No lo copie a un repositorio.

Antes de publicar, ejecute:

    rg -n -i 'password|secret|token|authorization:|api[_-]?key|client[_-]?id|\.env' . --glob '!*.png' --glob '!*.svg'

Las menciones genéricas de seguridad son normales; cualquier valor real requiere revisión y exclusión.

