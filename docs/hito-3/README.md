# Hito 3 · Detección y respuesta

El export de Kibana (reglas `DET-*` y dashboard) está en [`waf-siem/kibana-export.ndjson`](../../waf-siem/kibana-export.ndjson).

**Conexión app–WAF: opción B.** Juice Shop corre como el servicio `app` del `docker-compose.yml` con `expose: 3000` y sin `ports:`, así que desde fuera solo se llega por el WAF en `127.0.0.1:8080`. El puerto 3000 no queda publicado en la máquina; el único que puede saltarse el WAF es otro contenedor de la misma red de Docker, que en este entorno son solo Elastic, Kibana y Filebeat. El WAF escucha en `127.0.0.1` (`WAF_BIND`), no en la red de la universidad.

Scripts de evidencia (en `waf-siem/`):

- `./scripts/poc-redteam.sh` repite los PoC del H2 y dos pruebas de detección, con hora local, hora UTC, payload y código HTTP.
- `./scripts/flujo-usuario.sh` usa la app como cliente normal de punta a punta (registro, login, carrito, dirección, tarjeta de prueba, reseña, feedback, queja con PDF, checkout, cambio de contraseña) y marca cualquier 403.

## Reglas

Tres búsquedas guardadas en Discover, cada una sobre un ataque real por `:8080` con el WAF en DetectionOnly. En las capturas se fijaron (pin) `@timestamp`, `ruleId` y `data` para que se vean la hora, la regla y el payload.

| Regla | KQL | Ataque que detecta | Captura |
|---|---|---|---|
| DET-01 SQLi | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 942*` | UNION SQLi en `/rest/products/search` y bypass de login (PoC-01 y PoC-02 del H2). Reglas 942100/942190/942270 | [`02-regla-det-01-sqli.png`](02-regla-det-01-sqli.png) |
| DET-02 XSS | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 941*` | `<script>alert(1)</script>` en el parámetro `q` de la búsqueda | [`03-regla-det-02.xss.png`](03-regla-det-02.xss.png) |
| DET-03 Metodo | `fields.fuente : "waf-audit" and modsec.transaction.messages.details.ruleId : 911100` | Método `PROPFIND` fuera de `ALLOWED_METHODS` (escaneo de métodos) | [`04-regla-det-03-metodo.png`](04-regla-det-03-metodo.png) |

Nota: el IDOR del carrito (PoC-03) no aparece aquí a propósito. Es una petición válida con un id ajeno, así que el WAF no la marca; se detecta y corrige en el código (Hito 4).

El UNION SQLi dispara varias reglas de la familia 942 más el umbral 949110. El comodín `942*` las agrupa todas.

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

Salidas completas: [`poc-DetectionOnly.txt`](poc-DetectionOnly.txt), [`poc-On.txt`](poc-On.txt). Captura del bloqueo: [`06-waf-403-bloqueo.png`](06-waf-403-bloqueo.png).

## Exclusiones

Con el WAF en `On` se usó la app como cliente normal con `waf-siem/scripts/flujo-usuario.sh` (registro, login, carrito, dirección, tarjeta de prueba, reseña, feedback, queja con PDF, checkout y cambio de contraseña). La primera vuelta dio 5 bloqueos en acciones legítimas ([`flujo-usuario-antes.txt`](flujo-usuario-antes.txt)); `waf-siem/scripts/ver-bloqueos.sh` mostró qué regla los causó ([`bloqueos-antes.txt`](bloqueos-antes.txt)). El CRS sigue completo y en paranoia 1; no se desactivó ninguna familia de reglas.

| Regla | Ruta o parámetro | Qué se excluyó | Por qué es legítimo | Archivo |
|---|---|---|---|---|
| 911100 (método no permitido) | `PUT /api/BasketItems/:id`, `DELETE /api/BasketItems/:id`, `PUT /rest/products/:id/reviews`, `PATCH /rest/products/reviews` | Nada en el CRS: se agregaron `PUT PATCH DELETE` a `ALLOWED_METHODS` (tipo 4). | Son los métodos REST que usa la propia SPA para cambiar la cantidad, quitar productos, escribir y editar reseñas. Riesgo aceptado: esos tres métodos se aceptan en todas las rutas; la autorización de cada ruta la sigue haciendo la app. Métodos raros como `PROPFIND`, `TRACE` o `CONNECT` siguen bloqueados (DET-03). | `waf-siem/.env` (y `.env.example`) |
| 932260 (RCE: comando Unix directo) | `REQUEST_FILENAME` en `/rest/user/whoami` | Solo el target `REQUEST_FILENAME` de la 932260, solo en esa ruta exacta (`@streq`), regla `id:10002`. | La regla confunde el nombre del endpoint con el comando `whoami`. La SPA lo llama en cada carga para saber quién está logueado. Riesgo aceptado: en esa ruta la 932260 no revisa el nombre del archivo; parámetros, cookies y cabeceras siguen evaluados. | `waf-siem/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |

Efecto secundario que no es falso positivo: el feedback y la queja dieron 400 en la primera vuelta porque, sin la respuesta de `whoami`, el script mandó un JSON con `UserId` vacío y el WAF lo rechazó con la regla 200002 (cuerpo que no se puede parsear). Ese rechazo es correcto. Al arreglar `whoami` el JSON va completo y pasan.

Después del ajuste, la misma vuelta no tiene ningún 403 en acciones legítimas ([`flujo-usuario-despues.txt`](flujo-usuario-despues.txt)) y los ataques siguen bloqueados ([`poc-On.txt`](poc-On.txt)). Captura: [`07-exclusion-falso-positivo.png`](07-exclusion-falso-positivo.png).

## Demo Purple Team

- PoC que se repite en vivo: PoC-02 (UNION SQLi en la búsqueda) desde Burp o Postman por `:8080`, y PoC-01 como respaldo.
- Hora acordada: durante la presentación; la hora exacta de cada intento queda en `poc-redteam.sh` y en Kibana.
- Qué muestra el Equipo azul: el 403 en la respuesta, el evento en Discover con `DET-01 SQLi` (ruleId, payload y hora) y el pico en el dashboard `WAF - Blue Team`. Para contrastar, una acción normal (agregar al carrito) responde 200.

## Uso de IA

Los scripts `poc-redteam.sh`, `flujo-usuario.sh` y `ver-bloqueos.sh`, la exclusión `id:10002` y la redacción de este README se hicieron con ayuda de Claude (Anthropic). Las corridas, las capturas y la revisión de cada regla en Kibana las hizo Sebas.
