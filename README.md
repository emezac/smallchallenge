# Entrega — Technical Assessment AI

Este directorio es el paquete publicable de la entrega. Contiene dos
entregables independientes, sus diagramas, código y pruebas. Se ha preparado
para un repositorio Git: no contiene credenciales, variables `.env`, bases de
datos de evidencia, prompts completos, transcripciones, identificadores del
Hub, tenants OAuth, URLs temporales, grants ni capturas sin redactar.

## Contenido

| Directorio | Entregable | Punto de partida |
| --- | --- | --- |
| `parte1/` | Mejora acotada del comportamiento de recomendación en Agent Workflow | [Resumen](parte1/README.md) |
| `reto-b-mcp/` | Gateway MCP para una tarjeta simulada con confirmación humana | [README](reto-b-mcp/README.md) |

La evidencia pública conserva sólo resultados agregados y el contrato de
comportamiento. Los materiales privados de ejecución permanecen fuera de este
paquete por confidencialidad.

Los textos exactos de los prompts no se duplican aquí. Su fuente autoritativa
es la versión publicada en **Agent Workflow** del proyecto AIFindr; un revisor
con acceso autorizado puede inspeccionarla directamente en el sitio de
AIFindr.

## Revisión rápida

1. Lea el resumen de Parte 1 y sus diagramas before/after.
2. En Reto B, consulte arquitectura, máquina de estados y modelo de amenazas.
3. Con Ruby 3.4.1, ejecute las pruebas locales del gateway:

   ```sh
   cd reto-b-mcp
   BUNDLE_PATH=vendor/bundle bundle install
   BUNDLE_PATH=vendor/bundle bundle exec ruby bin/verify
   ```

   La evidencia registrada corresponde a 26 runs, 113 assertions y cero
   failures, errors o skips. Las pruebas no necesitan AIFindr, Auth0 ni ngrok.

## Límites y evolución

La integración demostrada usa datos simulados y una topología temporal. No se
presenta como un despliegue bancario productivo. La evolución técnica propuesta
está en [ROADMAP_PRODUCCION.md](ROADMAP_PRODUCCION.md); sus elementos son
explícitamente trabajo futuro, no funcionalidades ya implementadas.

Antes de publicar este directorio, siga [SANITIZATION.md](SANITIZATION.md) y
revise el diff final antes de añadirlo a GitHub.
