# Hito 3 · Detección y respuesta

El export de Kibana (reglas `DET-*` y dashboard) está en [`waf-siem/kibana-export.ndjson`](../../waf-siem/kibana-export.ndjson) (Stack Management → Saved Objects → Export, captura [`08-saved-objects-export.png`](08-saved-objects-export.png)).

**Conexión app–WAF: opción B.** Juice Shop corre como el servicio `app` del `docker-compose.yml` con `expose: 3000` y sin `ports:`, así que desde fuera solo se llega por el WAF en `127.0.0.1:8080`. El puerto 3000 no queda publicado en la máquina; el único que puede saltarse el WAF es otro contenedor de la misma red de Docker, que en este entorno son solo Elastic, Kibana y Filebeat. El WAF escucha en `127.0.0.1` (`WAF_BIND`), no en la red de la universidad.

Scripts de evidencia (en `waf-siem/`):

- `./scripts/poc-redteam.sh` repite los PoC del H2 y dos pruebas de detección, con hora local, hora UTC, payload y código HTTP.
- `./scripts/flujo-usuario.sh` usa la app como cliente normal de punta a punta (registro, login, carrito, dirección, tarjeta de prueba, reseña, feedback, queja con PDF, checkout, cambio de contraseña) y marca cualquier 403.

## Reglas

Cinco búsquedas guardadas en Discover (las tres mínimas de la guía y dos más), cada una sobre un ataque real por `:8080` con el WAF en DetectionOnly. En las capturas se fijaron (pin) `@timestamp`, `ruleId` y `data` para que se vean la hora, la regla y el payload.

| Regla | KQL | Ataque que detecta | Captura |
|---|---|---|---|
| DET-01 SQLi | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 942*` | UNION SQLi en `/rest/products/search` y bypass de login (PoC-01 y PoC-02 del H2). Reglas 942100/942190/942270 | [`02-regla-det-01-sqli.png`](02-regla-det-01-sqli.png) |
| DET-02 XSS | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 941*` | `<script>alert(1)</script>` en el parámetro `q` de la búsqueda | [`03-regla-det-02.xss.png`](03-regla-det-02.xss.png) |
| DET-03 Metodo | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 911100` | Método `PROPFIND` fuera de `ALLOWED_METHODS` (escaneo de métodos) | [`04-regla-det-03-metodo.png`](04-regla-det-03-metodo.png) |
| DET-04 PathTraversal | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 930*` | Descarga de `package.json.bak` desde `/ftp` con byte nulo codificado (`%2500`), la debilidad V-10. Regla 930130 (acceso a archivo restringido); la familia 930 también cubre `../` (930100/930110) | [`09-regla-det-04-path-traversal.png`](09-regla-det-04-path-traversal.png) |
| DET-05 Comandos | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 932*` | Inyección de comandos en la búsqueda: `q=jugo; uname -a` (932235, 932260) y `q=$(id)` (932130) | [`10-regla-det-05-comandos.png`](10-regla-det-05-comandos.png) |

Nota: el IDOR del carrito (PoC-03) no aparece aquí a propósito. Es una petición válida con un id ajeno, así que el WAF no la marca; se detecta y corrige en el código (Hito 4).

El UNION SQLi dispara varias reglas de la familia 942 más el umbral 949110. El comodín `942*` las agrupa todas.

DET-04 y DET-05 se agregaron después de la primera entrega. Se importan con `waf-siem/scripts/kibana-reglas.sh`, que también vuelve a exportar todos los objetos a `kibana-export.ndjson` (las búsquedas nuevas están solas en `waf-siem/kibana-det-04-05.ndjson`).

- **DET-04** es un ataque que sí funciona en la imagen de Docker: Juice Shop solo deja bajar `.md` y `.pdf` de `/ftp`, pero corta el nombre en `%00`. Con `%2500` el WAF ve `package.json.bak%00.md`, la app entrega `package.json.bak`. En `DetectionOnly` el archivo sale (200); en `On` el WAF lo bloquea.
- **Lo que DET-04 no ve:** la misma técnica con `coupons_2013.md.bak%2500.md` pasa en los dos modos. La 930130 reconoce `package.json` porque está en su lista de archivos sensibles, no porque entienda el byte nulo, y en paranoia 1 no hay otra regla que lo marque. Queda anotado como brecha: la corrección de fondo es en el código (`routes/fileServer.ts`), no en el WAF.
- **DET-05** detecta intentos: Juice Shop no pasa `q` a ninguna shell, así que en `DetectionOnly` la búsqueda solo devuelve una lista vacía. La regla sirve para ver al Equipo rojo probando inyección de comandos aunque no tenga éxito.

## Dashboard

- Nombre: `WAF - Blue Team`
- Paneles (Lens, sobre el data view `filebeat-*`):
  1. Eventos del WAF en el tiempo.
  2. Top de `ruleId`: qué reglas del CRS se disparan más.
  3. Top de `request.uri`: qué rutas reciben los ataques.
  4. Top de `client_ip`: de dónde vienen.
- Captura: [`05-dashboard-waf.png`](05-dashboard-waf.png)

## Detección y bloqueo con ataques reales

Los mismos ataques se lanzaron dos veces con `waf-siem/scripts/poc-redteam.sh`: primero con el WAF en `DetectionOnly` (registra y deja pasar) y luego en `On` (bloquea). Hora local de Guatemala; el log de auditoría del WAF guarda la hora en UTC (+6 h).

| Ataque | Payload | Regla que lo detecta | DetectionOnly | On |
|---|---|---|---|---|
| PoC-01 SQLi en el login | `email=' OR 1=1--` | DET-01 (942100) | 07:50:26 → 200 | 08:02:21 → **403** |
| PoC-02 UNION SQLi en la búsqueda | `q=qwert')) UNION SELECT id, email, password, '4',…,'10' FROM Users--` | DET-01 (942100, 942190, 942270) | 07:50:28 → 200 | 08:02:23 → **403** |
| XSS en la búsqueda | `q=<script>alert(1)</script>` | DET-02 (941100, 941110, 941160, 941390) | 07:50:33 → 200 | 08:02:27 → **403** |
| Método no permitido | `PROPFIND /rest/products/search` | DET-03 (911100) | 07:50:35 → 500 (lo responde la app) | 08:02:29 → **403** |
| PoC-03 IDOR del carrito | `GET /rest/basket/1` con token de jim | ninguna | 07:50:31 → 200 | 08:02:25 → 200 |

El IDOR pasa en los dos modos y es lo correcto desde el punto de vista del WAF: la petición es válida, solo cambia un id. Se corrige en el código en el Hito 4.

Salidas completas: [`poc-DetectionOnly.txt`](poc-DetectionOnly.txt), [`poc-On.txt`](poc-On.txt). Captura del bloqueo: [`06-waf-403-bloqueos.png`](06-waf-403-bloqueos.png).

### Ampliación: DET-04 y DET-05

Mismo procedimiento con `waf-siem/scripts/evidencia-h3b.sh`, que cambia el modo, corre los ataques y guarda las salidas con sufijo `-2`. Las horas exactas de cada intento están en esos archivos.

| Ataque | Payload | Regla | DetectionOnly | On |
|---|---|---|---|---|
| Respaldo por byte nulo | `GET /ftp/package.json.bak%2500.md` | DET-04 (930130) | 200, se descarga el archivo | **403** |
| Respaldo por byte nulo (brecha) | `GET /ftp/coupons_2013.md.bak%2500.md` | ninguna en paranoia 1 | 200 | 200 |
| Inyección de comandos | `q=jugo; uname -a` | DET-05 (932235, 932260) | 200, lista vacía | **403** |
| Inyección de comandos | `q=$(id)` | DET-05 (932130) | 200, lista vacía | **403** |

Salidas: [`poc-DetectionOnly-2.txt`](poc-DetectionOnly-2.txt), [`poc-On-2.txt`](poc-On-2.txt) y, con las exclusiones nuevas prendidas, [`poc-On-exclusiones-2.txt`](poc-On-exclusiones-2.txt).

## Exclusiones

Con el WAF en `On` se usó la app como cliente normal con `waf-siem/scripts/flujo-usuario.sh` (registro, login, carrito, dirección, tarjeta de prueba, reseña, feedback, queja con PDF, checkout y cambio de contraseña). La primera vuelta dio 5 bloqueos en acciones legítimas ([`flujo-usuario-antes.txt`](flujo-usuario-antes.txt)); `waf-siem/scripts/ver-bloqueos.sh` mostró qué regla los causó ([`bloqueos-antes.txt`](bloqueos-antes.txt)). El CRS sigue completo y en paranoia 1; no se desactivó ninguna familia de reglas.

| Regla | Ruta o parámetro | Qué se excluyó | Por qué es legítimo | Archivo |
|---|---|---|---|---|
| 911100 (método no permitido) | `PUT /api/BasketItems/:id`, `DELETE /api/BasketItems/:id`, `PUT /rest/products/:id/reviews`, `PATCH /rest/products/reviews` | Nada en el CRS: se agregaron `PUT PATCH DELETE` a `ALLOWED_METHODS` (tipo 4). | Son los métodos REST que usa la propia SPA para cambiar la cantidad, quitar productos, escribir y editar reseñas. Riesgo aceptado: esos tres métodos se aceptan en todas las rutas; la autorización de cada ruta la sigue haciendo la app. Métodos raros como `PROPFIND`, `TRACE` o `CONNECT` siguen bloqueados (DET-03). | `waf-siem/.env` (y `.env.example`) |
| 932260 (RCE: comando Unix directo) | `REQUEST_FILENAME` en `/rest/user/whoami` | Solo el target `REQUEST_FILENAME` de la 932260, solo en esa ruta exacta (`@streq`), regla `id:10002`. | La regla confunde el nombre del endpoint con el comando `whoami`. La SPA lo llama en cada carga para saber quién está logueado. Riesgo aceptado: en esa ruta la 932260 no revisa el nombre del archivo; parámetros, cookies y cabeceras siguen evaluados. | `waf-siem/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |
| 920420 (tipo de contenido no permitido) | `POST /socket.io/` con `Content-Type: text/plain;charset=UTF-8` | Solo la 920420, solo en la ruta exacta `/socket.io/` (`@streq`) y solo si el tipo es `text/plain`. Regla `id:10003` (encadenada). | Las notificaciones en tiempo real de Juice Shop usan socket.io. Antes de pasar a WebSocket, el navegador manda sus mensajes por POST con `text/plain`, que no está en la lista del CRS. Sin la exclusión, los avisos de la tienda no llegan. Riesgo aceptado: en esa ruta se acepta `text/plain`; cualquier otro tipo sigue revisado y el cuerpo sigue pasando por el resto del CRS. | `waf-siem/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |
| 932235 (inyección de comandos Unix) | `ARGS:json.message` en `PUT /rest/products/:id/reviews` y `PATCH /rest/products/reviews` | Solo el campo `message` de la 932235, solo en las dos rutas de reseñas. Regla `id:10004`. | La reseña «Muy rico; echo de menos la presentación en vidrio» se bloqueaba: la regla lee `; echo` como el comando `echo`. «Echo de menos» es español normal. La reseña se guarda en MarsDB y se muestra como texto; nunca llega a una shell. Riesgo aceptado: en ese campo la 932235 no revisa comandos; las demás 932* (932130, 932250, 932260), las de SQLi y las de XSS siguen revisándolo. El feedback (`/api/Feedbacks`) no se excluyó: el mismo texto ahí sigue dando 403. | `waf-siem/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |

Lo que no fue falso positivo: el feedback y la queja dieron 400 en las dos vueltas. La causa estaba en el script, no en el WAF. `/rest/user/whoami` lee la sesión de la cookie `token` (como la manda el navegador) y no de la cabecera `Authorization`; el script solo mandaba la cabecera, así que `whoami` devolvía un usuario vacío y el JSON salía con `UserId` vacío. El WAF rechazó ese cuerpo con la regla 200002 (JSON que no se puede parsear), que es el comportamiento correcto. Se corrigió el script para mandar también la cookie, igual que la SPA.

Después del ajuste, la misma vuelta no tiene ningún 403 en acciones legítimas ([`flujo-usuario-despues.txt`](flujo-usuario-despues.txt)) y los ataques siguen bloqueados ([`poc-On.txt`](poc-On.txt)). Captura: [`07-exclusion-falso-positivo.png`](07-exclusion-falso-positivo.png).

### Ampliación: exclusiones 10003 y 10004

`flujo-usuario.sh` ahora también abre la conexión de socket.io como lo hace la SPA al cargar (handshake por GET y primer mensaje por POST `text/plain`) y escribe una reseña en español. Con el WAF en `On` y las exclusiones nuevas apagadas (`scripts/alternar-exclusiones.sh off`) esas dos acciones dan 403 ([`flujo-usuario-antes-2.txt`](flujo-usuario-antes-2.txt)); `ver-bloqueos.sh` muestra la regla y el campo ([`bloqueos-antes-2.txt`](bloqueos-antes-2.txt)). Con las exclusiones prendidas el flujo completo queda sin 403 ([`flujo-usuario-despues-2.txt`](flujo-usuario-despues-2.txt)) y los ataques siguen bloqueados ([`poc-On-exclusiones-2.txt`](poc-On-exclusiones-2.txt)), incluido DET-05: la exclusión 10004 no toca el parámetro `q` de la búsqueda. Capturas: [`11-exclusion-socketio.png`](11-exclusion-socketio.png) y [`12-exclusion-resena.png`](12-exclusion-resena.png).

Antes de la corrida real, las dos exclusiones se probaron con el mismo CRS (v4) en un motor compatible (Coraza) para confirmar que son estrechas: `text/plain` en otra ruta sigue bloqueado por 920420, otro tipo de contenido en `/socket.io/` también, y en la reseña `; uname -a` y `$(id)` siguen bloqueados por 932260 y 932130.

## Demo Purple Team

El guion completo del video está en [`docs/guion-video.md`](../guion-video.md) y la matriz que une requisito, amenaza, PoC, regla, WAF y corrección en [`docs/trazabilidad-y-riesgo-residual.md`](../trazabilidad-y-riesgo-residual.md).


- PoC que se repite en vivo: PoC-02 (UNION SQLi en la búsqueda) desde Burp o Postman por `:8080`, y PoC-01 como respaldo.
- Hora acordada: durante la presentación; la hora exacta de cada intento queda en `poc-redteam.sh` y en Kibana.
- Qué muestra el Equipo azul: el 403 en la respuesta, el evento en Discover con `DET-01 SQLi` (ruleId, payload y hora) y el pico en el dashboard `WAF - Blue Team`. Para contrastar, una acción normal (agregar al carrito) responde 200.

## Uso de IA

Los scripts `poc-redteam.sh`, `flujo-usuario.sh` y `ver-bloqueos.sh`, la exclusión `id:10002` y la redacción de este README se hicieron con ayuda de Claude (Anthropic). Las corridas, las capturas y la revisión de cada regla en Kibana las hizo Sebas. La ampliación (DET-04, DET-05, exclusiones `10003` y `10004`, `evidencia-h3b.sh`, `alternar-exclusiones.sh`, `modo-waf.sh` y `kibana-reglas.sh`) también se preparó con Claude; los falsos positivos se buscaron probando acciones legítimas de la tienda contra el CRS antes de la corrida real.
