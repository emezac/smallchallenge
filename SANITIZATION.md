# Control de publicación y sanitización

## Alcance de esta copia

Se incluyeron código fuente, pruebas locales, diagramas, documentación de
diseño y resultados agregados. No se incluyeron datos que permitan acceder,
identificar o reconstruir una sesión de prueba.

## Exclusiones deliberadas

- Archivos `.env`, secretos OAuth/JWKS, claves de auditoría y llaves privadas.
- Bases SQLite, WAL/SHM, grants, cookies, tokens, logs y resultados crudos.
- Prompts completos, IDs/versiones de prompts, KB, chunks y transcripciones.
- IDs de proyectos, organizaciones o clientes, nombres personales, tenants,
  callbacks y URLs ngrok de una sesión concreta.
- Datasets y resultados privados de Parte 1. Se conserva sólo un ejemplo
  sintético, la rúbrica y los resultados agregados.
- Capturas o vídeo no redactados.

## Verificación antes de subir

Desde `challenge-entrega/`, ejecute una inspección textual y revise todo
hallazgo antes de publicar:

```sh
rg -n -i 'password|secret|token|authorization:|api[_-]?key|client[_-]?id|ngrok-free|auth0\.com|\.env' . \
  --glob '!Gemfile.lock' --glob '!*.png' --glob '!*.svg'
```

Las menciones genéricas a `.env`, `token`, Auth0 o secretos en guías y pruebas
son normales: deben describir controles o placeholders, nunca valores reales.
Verifique también `git status --ignored` y el contenido de cada archivo que se
vaya a añadir. No publique este paquete si se ha copiado una captura, archivo
de configuración o base de datos adicional sin revisarla.
