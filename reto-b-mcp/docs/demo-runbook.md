# Guía de revisión y demostración — Gateway MCP (Reto B)

Esta guía permite revisar el proyecto sin experiencia previa con Ruby on Rails. La idea es deliberadamente simple:

1. comprobar primero el comportamiento local, sin cuentas externas ni secretos;
2. levantar los dos procesos que forman el gateway;
3. sólo si se quiere comprobar la integración real, exponer el servidor local con ngrok y conectarlo a AIFindr mediante Auth0.

El dominio bancario es simulado. La única tarjeta de demostración es `card_demo`; no se conecta a sistemas bancarios reales ni se debe proporcionar información personal.

## Panel de evidencia legible

Antes de la demostración interactiva se puede mostrar un resumen humano de lo que ya quedó registrado, sin abrir JSON ni exponer secretos:

```bash
./bin/show-evidence
```

El script sólo lee `evidence/manifest.json`; no inicia el servidor, worker, ngrok ni OAuth. Presenta la suite local, la allowlist exacta, el recorrido confirmado y los límites `NOT_RUN`. Para ejecutar también las pruebas locales antes del resumen, con Ruby 3.4.1 activo:

```bash
./bin/show-evidence --verify
```

Desde la raíz de la entrega (`challenge2`), el visor de Parte 1 se invoca como `./bin/show-evidence part1`; para ambos paneles juntos: `./bin/show-evidence all`.

## Qué se está demostrando

![Arquitectura end-to-end](diagrams/mcp-end-to-end.svg)

El proyecto implementa un servidor MCP que ofrece únicamente tres herramientas al agente de AIFindr:

| Herramienta | Qué hace | ¿Cambia el estado? |
|---|---|---|
| `get_card_status` | Devuelve el estado de la tarjeta simulada. | No |
| `propose_action` | Crea una propuesta de bloqueo; nunca bloquea por sí misma. | Sí, crea la propuesta |
| `get_action_status` | Consulta el estado de esa propuesta mediante su alias. | No |

La acción irreversible no viaja por MCP: la persona abre una página local de confirmación y aprueba o rechaza explícitamente la propuesta. Un *worker* independiente realiza después el bloqueo simulado y guarda una bitácora HMAC encadenada.

![Máquina de estados de la propuesta](diagrams/action-state-machine.svg)

La separación importa: el modelo puede ayudar a consultar y proponer, pero no puede confirmar la acción en nombre de la persona.

## Componentes, en lenguaje no-Rails

No hace falta aprender Rails para ejecutar la demo. Estos son los únicos procesos y archivos relevantes:

| Elemento | Función | Cómo se usa en la demo |
|---|---|---|
| `bin/server` | Servidor web local. Atiende `/mcp`, las páginas de confirmación y `/health/live`. | Se deja ejecutándose en una terminal. |
| `bin/worker` | Proceso en segundo plano. Caduca y ejecuta propuestas confirmadas. | Se deja ejecutándose en otra terminal. |
| `storage/gateway.sqlite3` | Base de datos SQLite, un único archivo local. | Se crea/usa automáticamente; no requiere instalar un servidor de base de datos. |
| `bin/verify` | Pruebas automatizadas. | Es la primera comprobación y no necesita `.env`. |
| `bin/doctor` | Revisa la configuración local y el estado del almacenamiento. | Requiere un `.env` local válido. |
| Auth0 + ngrok | Sólo para que AIFindr alcance el proceso que corre en el ordenador local. | Opcional para las pruebas locales; obligatorio para el recorrido real desde AIFindr. |

## 1. Requisitos previos

Se necesita lo siguiente:

- Ruby **3.4.1**. Compruébalo con `ruby -v`.
- Bundler, el gestor de dependencias de Ruby (`gem install bundler` si no está disponible).
- SQLite, normalmente incluido en macOS y en la mayoría de distribuciones Linux.
- Para el recorrido externo: una cuenta de ngrok y el tenant Auth0 configurado para el reto. No hacen falta para ejecutar las pruebas.

Desde una terminal, entra en la carpeta del proyecto:

```bash
cd /ruta/a/reto-b-mcp
ruby -v
BUNDLE_PATH=vendor/bundle bundle install
```

La salida de `ruby -v` debe comenzar por `ruby 3.4.1`. Si muestra otra versión, activa primero el gestor de Ruby que use el equipo (por ejemplo, rvm, rbenv o asdf). No conviene continuar con la versión Ruby incluida por defecto en versiones antiguas de macOS.

`BUNDLE_PATH=vendor/bundle` guarda las gemas dentro del proyecto, en vez de modificar las gemas globales del sistema.

## 2. Comprobación local mínima — no requiere credenciales

Esta es la forma más rápida de comprobar que el código entregado funciona. No crea una cuenta, no abre un túnel y no lee secretos.

```bash
cd /ruta/a/reto-b-mcp
BUNDLE_PATH=vendor/bundle bundle exec ruby bin/verify
```

Resultado esperado al final:

```text
26 runs, 113 assertions, 0 failures, 0 errors, 0 skips
```

La suite cubre autorización JWT, los tres *tools* MCP, idempotencia, confirmación humana, expiración, reintentos, auditoría HMAC, UI y arranque de la aplicación. El número de pruebas puede aumentar en futuras versiones; lo importante es que no haya `failures` ni `errors`.

También puede comprobarse que la aplicación arranca:

```bash
BUNDLE_PATH=vendor/bundle bundle exec ruby test/rails_boot.rb
```

Esta comprobación no equivale a una conexión real con AIFindr. Verifica únicamente que la aplicación web puede inicializarse localmente.

## 3. Crear y proteger la configuración local

El archivo `.env` contiene valores sensibles y **no se entrega ni se sube al repositorio**. Para las pruebas automatizadas no hace falta crearlo.

Si se desea iniciar el servidor local, se puede generar una plantilla segura una sola vez:

```bash
BUNDLE_PATH=vendor/bundle bundle exec ruby bin/setup-local-env
```

El comando se detiene si ya existe `.env`, genera claves locales aleatorias y deja el archivo con permisos `0600` (sólo legible por su propietario). No imprime secretos.

> `bin/setup-local-env` prepara secretos locales, pero no crea una cuenta Auth0 ni descarga las claves públicas del tenant. Los campos de endpoint que deja son un ejemplo de la sesión de evidencia; para una nueva integración hay que sustituirlos por el origen ngrok y la configuración Auth0 propia de esa sesión.

Los campos más relevantes son:

| Variable | Significado | Cuándo se necesita |
|---|---|---|
| `PUBLIC_ORIGIN` | URL pública HTTPS del gateway, por ejemplo `https://nombre.ngrok.app`. | Sólo al usar ngrok/AIFindr. |
| `AUDIT_KEY` y `SECRET_KEY_BASE` | Secretos locales para la auditoría y la aplicación. | Siempre que se arranque con `.env`; no compartirlos. |
| `OAUTH_ISSUER` | Dominio emisor de tokens del tenant Auth0. | Sólo OAuth real. |
| `OAUTH_JWKS_FILE` | Ruta a la copia local del JWKS público de Auth0. | Sólo OAuth real. |
| `BUNDLE_PATH` | Carpeta local donde Bundler encuentra las gemas. | Recomendado en todos los comandos. |

Para cargar el archivo de forma segura se usa siempre `bin/with-local-env`; valida que `.env` conserve el permiso `0600` antes de ejecutar cualquier comando:

```bash
bin/with-local-env bundle exec ruby bin/doctor
```

Una configuración completa devuelve un JSON con, entre otros, estos indicadores:

```text
database: PASS
audit: PASS
oauth_configuration: PASS_LOCAL_ONLY
aifindr_live_connection: NOT_CHECKED_BY_DOCTOR
```

El último indicador es intencional: `doctor` no intenta acceder a AIFindr. Evita que una comprobación local dependa de red, credenciales externas o de la disponibilidad de otro servicio.

## 4. Iniciar la demo local

Abra **dos terminales** en la carpeta `reto-b-mcp`. Ambos procesos deben permanecer abiertos mientras se hace la demostración.

En la primera terminal, inicie el servidor:

```bash
bin/with-local-env bundle exec ruby bin/server -C config/puma.rb
```

Por defecto escucha sólo en `127.0.0.1:9292`; esto significa “sólo este ordenador”. Compruebe que está vivo desde otra terminal:

```bash
curl -i http://127.0.0.1:9292/health/live
```

Se espera un código HTTP `200`.

En la segunda terminal, inicie el worker:

```bash
bin/with-local-env bundle exec ruby bin/worker
```

El worker no abre un navegador. Su trabajo es buscar propuestas confirmadas, ejecutar el bloqueo simulado, registrar el resultado y caducar propuestas que no se confirmen a tiempo.

La página de confirmación usa cookies `Secure`, `HttpOnly`, con prefijo `__Host-` y `SameSite=Lax`. `Lax` es intencional: el enlace llega desde AIFindr a un origen HTTPS separado (ngrok) y debe sobrevivir al redirect inicial. La acción de confirmar sigue requiriendo una sesión por acción, token CSRF y validación de `Origin`/Fetch Metadata.

Como comprobación de integridad de la auditoría local:

```bash
bin/with-local-env bundle exec ruby bin/verify-audit
```

Resultado esperado:

```text
Audit verification passed
```

## 5. Exponer el gateway temporalmente con ngrok

Este paso sólo es necesario para la demostración desde AIFindr. ngrok crea una URL HTTPS pública que redirige de forma temporal al servidor que ya está corriendo en `127.0.0.1:9292`.

En una tercera terminal:

```bash
ngrok http 127.0.0.1:9292 --inspect=false --log=false
```

Copie la URL `https://…ngrok.app` que muestra ngrok. Compruebe antes de configurar servicios externos:

```bash
curl -i https://SU-DOMINIO.ngrok.app/health/live
```

Debe responder `200`. El endpoint MCP completo siempre termina en `/mcp`:

```text
https://SU-DOMINIO.ngrok.app/mcp
```

### Si ngrok genera una URL distinta

Una URL gratuita de ngrok puede cambiar al reiniciar el túnel. Si cambia, actualice los cuatro lugares siguientes antes de reconectar:

1. `PUBLIC_ORIGIN` dentro de `.env` — sin `/mcp` final.
2. El identificador/audience de la API de Auth0: `PUBLIC_ORIGIN/mcp`.
3. El endpoint MCP registrado en AIFindr: `PUBLIC_ORIGIN/mcp`.
4. La conexión OAuth en AIFindr, para emitir un token para el nuevo audience.

Después reinicie `bin/server` y `bin/worker`, ejecute `bin/doctor` y vuelva a conectar el MCP. Una discrepancia de una barra, protocolo o dominio entre esos valores causa normalmente errores `401`, `403` o `invalid audience`.

La guía detallada de Auth0, JWKS y AIFindr está en [auth0-ngrok.md](auth0-ngrok.md). ngrok es un mecanismo de demostración, no un despliegue de producción.

## 6. Recorrido completo en AIFindr

Con el servidor, worker y ngrok activos, configure el MCP según [aifindr-integration-contract.md](aifindr-integration-contract.md). El contrato exige un token OAuth RS256 válido, emitido para el audience exacto `PUBLIC_ORIGIN/mcp`.

El siguiente guion es suficiente para una demostración de punta a punta:

| Paso | Acción en AIFindr o navegador | Resultado observable |
|---:|---|---|
| 1 | Conecte el MCP mediante OAuth. | El servidor acepta el token; no hay 401/403. |
| 2 | Pida el estado de la tarjeta demo. | AIFindr llama `get_card_status` para `card_demo`; deja claro que se trata de datos simulados. |
| 3 | Pida bloquear la tarjeta porque se perdió. | AIFindr llama `propose_action` con `CARD_BLOCK` y `LOST_CARD`; devuelve un `action_alias`, estado `PENDING_CONFIRMATION` y una URL de confirmación. |
| 4 | Abra esa URL en un navegador. | Se muestra una página de revisión humana; la acción aún no está ejecutada. |
| 5 | Seleccione **Confirmar**. | El estado pasa a `CONFIRMED`; la confirmación queda fuera del protocolo MCP. |
| 6 | Espere unos segundos con el worker activo. | El worker lleva la propuesta a `EXECUTING` y después a `EXECUTED`. |
| 7 | Pida de nuevo el estado de la propuesta, usando el `action_alias`. | `get_action_status` informa `EXECUTED`. |
| 8 | Pida otro `get_card_status`. | La tarjeta simulada aparece como `BLOCKED`. |
| 9 | Ejecute `bin/verify-audit`. | La bitácora encadenada HMAC valida la evidencia local. |

El estado de la propuesta y el estado de la tarjeta se consultan por separado a propósito: una propuesta puede haber sido confirmada y todavía estar esperando al worker. No se debe presentar `CONFIRMED` como si fuera un bloqueo ya ejecutado.

La evidencia registrada de la sesión de integración incluida en el proyecto está en [`evidence/manifest.json`](../evidence/manifest.json) y [test-evidence.md](test-evidence.md): muestra la transición `ACTIVE → PENDING_CONFIRMATION → CONFIRMED → EXECUTED` y la tarjeta finalmente `BLOCKED`.

## 7. Restablecer sólo el escenario sintético

Para repetir la demo se puede restablecer exclusivamente la tarjeta y las acciones sintéticas. Es una operación protegida: exige una variable explícita y una confirmación literal.

```bash
DEMO_RESET_ALLOWED=1 bin/with-local-env bundle exec ruby bin/demo-reset --confirm-synthetic-reset
```

No ejecute ese comando contra datos reales. El script se niega a continuar si detecta indicadores de producción, una acción activa o un estado ambiguo.

## Problemas frecuentes

| Síntoma | Causa probable | Qué revisar |
|---|---|---|
| `ruby -v` no muestra 3.4.1 | Se está usando el Ruby del sistema. | Active rvm/rbenv/asdf y repita la comprobación. |
| `bundle` no se encuentra | Bundler no está instalado para ese Ruby. | Ejecute `gem install bundler` con Ruby 3.4.1 activo. |
| `Permission denied` o `.env must have 0600 permissions` | El archivo de secretos es legible por otros usuarios. | Ejecute `chmod 600 .env`; no lo añada a Git. |
| `doctor` informa OAuth incompleto | Faltan `OAUTH_ISSUER` o el archivo JWKS público. | Complete Auth0/JWKS siguiendo [auth0-ngrok.md](auth0-ngrok.md). |
| `401` al conectar AIFindr | Falta token, issuer incorrecto o firma inválida. | Compruebe tenant, JWKS y que el token sea RS256. |
| `403` o `invalid audience` | Auth0 y AIFindr no usan el mismo endpoint `/mcp`. | Compare exactamente los cuatro valores indicados en “Si ngrok genera una URL distinta”. |
| La propuesta queda `CONFIRMED` | El worker no está iniciado o no puede acceder a SQLite. | Mantenga `bin/worker` abierto y ejecute `bin/doctor`. |
| ngrok no responde `200` | El servidor local no está activo o el túnel apunta a otro puerto. | Primero compruebe `http://127.0.0.1:9292/health/live`, después reinicie ngrok. |
| La auditoría falla | Se modificó la base de datos o la clave HMAC cambió. | No edite SQLite manualmente; use una configuración coherente y vuelva a ejecutar las pruebas. |

## Límites conocidos y criterio de entrega

- El bloqueo, tarjeta y backend son simulados deliberadamente; no se realizan operaciones financieras reales.
- La confirmación humana es un enlace de demostración de un solo uso y no sustituye una UX de banca de producción.
- El JWKS se mantiene como copia local para hacer el ejercicio reproducible; una implementación productiva usaría rotación y obtención segura de claves.
- ngrok proporciona conectividad temporal para el video y la validación del reto; no es el despliegue final.
- La prueba automatizada local y la evidencia de integración son complementarias: la primera garantiza comportamiento reproducible y la segunda registra que el recorrido real con AIFindr fue ejercitado.

Con las secciones 2, 4 y 6 se cubren, respectivamente, calidad automatizada, operación local e integración end-to-end. Ninguna de ellas requiere conocimientos previos de Rails para ser revisada.
