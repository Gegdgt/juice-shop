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

## Exclusiones

*Instrucción: el WAF ya está en `MODSEC_RULE_ENGINE=On`. Cada fila es un falso
positivo encontrado usando la app como usuario normal. La exclusión más pequeña
posible; no se apaga el CRS. Los tipos y qué investigar si el ejemplo no
aplica están en la guía del Equipo azul, sección Exclusiones.*

| Regla | Ruta o parámetro | Qué se excluyó | Por qué es legítimo | Archivo |
|---|---|---|---|---|
|  |  |  |  | `waf-siem/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |

## Demo Purple Team

- PoC que se repite en vivo:
- Hora acordada:
- Qué muestra el Equipo azul (detección y bloqueo):
