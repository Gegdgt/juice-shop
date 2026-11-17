# Hito 2 · Pipeline y ataque

**Estado:** pipeline funcionando desde la corrida #1 (16 de noviembre de 2026). PoC del Equipo rojo pendientes.

## Pipeline

- Workflow: [`.github/workflows/devsecops.yml`](../../.github/workflows/devsecops.yml), adaptado de la plantilla del curso.
- Corrida de evidencia: [DevSecOps #1](https://github.com/Gegdgt/juice-shop/actions/runs/43922280752), commit `6645774` en `master`. Terminó en *Success* en 3 min 39 s, con los cuatro jobs en verde y cuatro artefactos: `semgrep`, `sca`, `sbom.cdx.json` y `zap`.
- Modo del gate: `reporte`.
- Workflows originales: los 16 del proyecto se movieron, sin editarlos, a [`.github/workflows-upstream/`](../../.github/workflows-upstream/README.md). GitHub Actions solo ejecuta lo que está en `.github/workflows/`, así que quedan deshabilitados.

### Qué se adaptó a Juice Shop

Se conservan los cuatro jobs, el gate y los artefactos de la plantilla.

| Job | Cambio | Por qué |
|---|---|---|
| SAST | Ninguno | Semgrep recorre el árbol de archivos; no depende de npm |
| SCA | Genera los lockfiles en el runner y audita dos proyectos: el servidor (raíz) y `frontend/`. El gate suma high y critical leyendo los dos JSON | El repo no versiona `package-lock.json` (`.npmrc`: `package-lock=false`) y `npm audit` lo exige. Se usa npm 11.19.1, el del CI original: con npm 10 falla el lockfile del frontend |
| SBOM | Genera los lockfiles antes de correr Syft | Sin lockfile, Syft no ve las dependencias npm |
| DAST | Construye la imagen con el `Dockerfile` del fork, la levanta en el puerto 3000 y espera dos URL antes de escanear | El escaneo corre sobre el código de este repositorio, no sobre la imagen pública, y así verá las correcciones del Hito 4. El 8080 es el del WAF y no se usa en el runner |

### Umbral del gate y justificación

Propuesta del Equipo azul, pendiente de acordar entre los dos.

| Control | Herramienta | Umbral | Qué hicieron con los hallazgos |
|---|---|---|---|
| SAST | Semgrep (`p/default` y `p/owasp-top-ten`) | 0 hallazgos de severidad ERROR | Corrida #1: el gate superó el umbral (hay hallazgos ERROR) y, por estar en `reporte`, no detuvo el pipeline. Falta contar los hallazgos en `semgrep.sarif` y revisar si aparecen V-01 y V-02 de la [etapa V](../hito-1/03b-PASTA-5-Vulnerabilidades.md) |
| SCA | `npm audit`, solo dependencias de producción | 0 vulnerabilidades high o critical | Línea base medida en local el 16 de noviembre de 2026 con los mismos comandos: servidor 12 high y 6 critical; frontend 1 high. Corrida #1: el gate superó el umbral, como se esperaba. Falta confirmar las cifras con el artefacto `sca` |
| SBOM | Syft, CycloneDX | El artefacto `sbom.cdx.json` se publica | Inventario de componentes; no tiene umbral |
| DAST | ZAP baseline | 0 alertas de riesgo alto | Corrida #1: el gate no superó el umbral. Falta revisar las alertas medias y bajas en el artefacto `zap` |

**Por qué `reporte` y no `bloqueo`.** Juice Shop es vulnerable a propósito. Con 19 dependencias high o critical de línea base, el modo `bloqueo` dejaría el pipeline en rojo en cada push sin decir nada nuevo. En `reporte` los controles corren, publican sus reportes y el pipeline solo falla si una herramienta no puede ejecutarse. Los umbrales quedan escritos para el Hito 4: una corrección no debe sumar hallazgos sobre esta línea base.

**Uso de IA.** El workflow se adaptó con Claude (Anthropic, modelo Claude Fable 5.2) a partir de la plantilla del curso. Los comandos de SCA se probaron en local antes del push y los cuatro jobs corrieron en la corrida #1. El grupo revisa el diff antes de darlo por bueno.

## PoC del Equipo rojo

Tres vulnerabilidades reales de Juice Shop, todas por `http://localhost:8080` con el WAF en `DetectionOnly`. Confirmadas en Burp Repeater el 17 de noviembre de 2026.

- Reporte de ZAP (sesión de escritorio): [`reporte-zap-redteam.html`](reporte-zap-redteam.html). Es un **baseline**: ZAP reportó 4 alertas Medias y 2 Informativas, todas de configuración (Content-Security-Policy ausente y flags de cookies; CWE-693 y CWE-264). No encontró la inyección ni el IDOR porque Juice Shop es una SPA de Angular y el spider no descubre los endpoints de la API; esas vulnerabilidades se confirman a mano con Burp, abajo. El job de ZAP del pipeline es el control automático; esta sesión es la evidencia del Equipo rojo.

| ID | Vulnerabilidad | Dónde (método y ruta por :8080) | OWASP Top 10:2025 | CWE | Vector CVSS v3.1 | Puntaje |
|---|---|---|---|---|---|---|
| PoC-01 | Bypass de autenticación por SQLi en el login | `POST /rest/user/login` | A05 Injection | CWE-89 | `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` | 9.8 Crítica |
| PoC-02 | Exfiltración de credenciales por UNION SQLi en la búsqueda | `GET /rest/products/search?q=` | A05 Injection | CWE-89 | `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N` | 7.5 Alta |
| PoC-03 | Acceso al carrito de otro usuario (IDOR) | `GET /rest/basket/{id}` | A01 Broken Access Control | CWE-639 | `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N` | 6.5 Media |

Las tres salen de la [etapa V de PASTA](../hito-1/03b-PASTA-5-Vulnerabilidades.md): PoC-01 es V-02, PoC-02 es V-01 y PoC-03 es V-03.

### PoC-01 · SQLi en el login (CWE-89)

- **Payload (campo `email`):** `' OR 1=1--`
- **Captura de Burp Repeater:** [`03-poc-sqli.png`](03-poc-sqli.png).
- **Cómo repetirlo en Postman:** carpeta 2 → *SQLi en el login*. La variable `poc_sqli_login` ya trae el payload.
- **Resultado observado:** `HTTP 200 OK`, `Content-Length: 784`. La respuesta trae `authentication.token`: se entra como `admin@juice-sh.op` sin contraseña. Hora del envío: 01:02 (07:02:21 UTC).
- **Justificación del CVSS, métrica por métrica:**
  - **AV:N** — se explota por HTTP, de forma remota.
  - **AC:L** — un payload fijo, sin condiciones previas.
  - **PR:N** — no hace falta cuenta; el objetivo es saltarse el login.
  - **UI:N** — ninguna interacción de otra persona.
  - **S:U** — el impacto queda dentro de la aplicación.
  - **C:H / I:H / A:H** — se obtiene la sesión de administrador: lectura, modificación y borrado de datos de la tienda.
  - **Puntaje: 9.8 (Crítica).**

### PoC-02 · UNION SQLi en la búsqueda (CWE-89)

- **Payload (parámetro `q`):** `qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9','10' FROM Users--` (10 columnas: 7 del modelo `Products` más `createdAt`, `updatedAt` y `deletedAt`).
- **Captura de Burp Repeater:** [`04-poc-sqli-search.png`](04-poc-sqli-search.png).
- **Cómo repetirlo en Postman:** carpeta 2 → *SQLi en la busqueda*. La variable `poc_busqueda` trae el payload de partida; para la exfiltración completa se pega este UNION.
- **Resultado observado:** `HTTP 200 OK`, `Content-Length: 4978`. La respuesta devuelve los correos y los hashes de todos los usuarios metidos entre los productos. Hora del envío: 01:08 (07:08:30 UTC).
- **Justificación del CVSS, métrica por métrica:**
  - **AV:N / AC:L / PR:N / UI:N** — igual que PoC-01: remoto, simple, sin cuenta ni interacción.
  - **S:U** — no cambia de componente.
  - **C:H** — se leen correos y hashes de todas las cuentas.
  - **I:N / A:N** — el UNION solo lee; no modifica ni tira el servicio.
  - **Puntaje: 7.5 (Alta).**

### PoC-03 · IDOR en el carrito (CWE-639)

- **Petición:** `GET /rest/basket/1` con el token `Authorization: Bearer ...` de la propia cuenta de prueba (`jim@juice-sh.op`). Devuelve el carrito de otro usuario.
- **Captura de Burp Repeater:** [`05-poc-idor.png`](05-poc-idor.png).
- **Nota para el Equipo azul:** el WAF **no** bloquea esto; es una petición válida con un id ajeno. Se detecta y corrige en el código (Hito 4), no con una regla del CRS. Por eso es el candidato a corrección del H4.
- **Cómo repetirlo en Postman:** carpeta 2 → *IDOR: carrito de otro usuario*. Pon tu token y `poc_basket_ajeno=1`.
- **Resultado observado:** `HTTP 200 OK`, `Content-Length: 1994`. Se obtiene el carrito de otra cuenta con el token propio. Hora del envío: 01:10 (07:10:45 UTC).
- **Justificación del CVSS, métrica por métrica:**
  - **AV:N / AC:L** — remoto y directo.
  - **PR:L** — hace falta una sesión válida (cualquier cuenta de prueba).
  - **UI:N / S:U.**
  - **C:H** — se accede a datos de otros usuarios. *(Si consideras que el contenido de un carrito es poco sensible, baja a `C:L` y el puntaje queda 4.3.)*
  - **I:N / A:N.**
  - **Puntaje: 6.5 (Media).**

## Registro de ataques

Una fila por intento. Las horas están en hora local de Guatemala (UTC−6). Se usó la cuenta de prueba `jim@juice-sh.op`.

| Fecha | Hora | Quién | Herramienta | Método y ruta | Payload | Respuesta |
|---|---|---|---|---|---|---|
| 2026-11-17 | 00:49 | Sebas | ZAP | Spider + escaneo sobre `:8080` | — | reporte baseline (4 Medias, 2 Info) |
| 2026-11-17 | 01:02 | Sebas | Burp | `POST /rest/user/login` | `' OR 1=1--` | 200, token de admin (784 B) |
| 2026-11-17 | 01:08 | Sebas | Burp | `GET /rest/products/search?q=` | `qwert')) UNION SELECT … FROM Users--` | 200, credenciales (4978 B) |
| 2026-11-17 | 01:10 | Sebas | Burp | `GET /rest/basket/1` | token propio, id ajeno | 200, carrito ajeno (1994 B) |
| 2026-11-17 | __:__ | Sebas | Postman | `POST /rest/user/login` | `poc_sqli_login` | *pendiente de repetir* |
| 2026-11-17 | __:__ | Sebas | Postman | `GET /rest/products/search?q=` | `poc_busqueda` | *pendiente de repetir* |
| 2026-11-17 | __:__ | Sebas | Postman | `GET /rest/basket/1` | `poc_basket_ajeno` | *pendiente de repetir* |
