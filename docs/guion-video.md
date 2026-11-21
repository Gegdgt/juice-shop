# Guion del video · H1 a H3 con demo en vivo

Sigue la estructura de las instrucciones del curso. La demo usa **una sola vulnerabilidad de principio a fin: PoC-01, SQLi en el login** (V-02, RS-03, T-07). Se eligió esa porque es la más grave (CVSS 9.8, se entra como admin sin contraseña) y pasa por todo el ciclo: el Equipo rojo la explota, Kibana la detecta (DET-01), el WAF la bloquea en `On` y el H4 la corrige en el código. El IDOR no sirve para la demo completa porque el WAF no lo ve.

Duración pensada: 15 a 18 minutos.

## Antes de grabar

Hacerlo con calma un rato antes; son unos 15 minutos.

1. **Entorno con la imagen pública (vulnerable).** Desde `waf-siem/`:
   ```bash
   unset COMPOSE_FILE
   docker compose up -d
   docker compose images app        # tiene que decir bkimminich/juice-shop
   ```
2. **Evidencia de las reglas y exclusiones nuevas** (si no se ha corrido):
   ```bash
   ./scripts/evidencia-h3b.sh
   ./scripts/kibana-reglas.sh
   ```
3. **Ejemplo de build frenado por el gate.** Hacer push y luego, en GitHub: Actions → DevSecOps → Run workflow → `gate: bloqueo`. Tarda unos 4 minutos y termina en rojo. Anotar el número de corrida en `docs/hito-2/README.md`.
4. **Dejar el WAF en `DetectionOnly`** para empezar la demo: `./scripts/modo-waf.sh DetectionOnly`.
5. **Pestañas listas:**
   - Tienda en `http://127.0.0.1:8080`, con sesión iniciada como `jim@juice-sh.op`.
   - Burp, en Repeater, pestaña 1, con la petición de PoC-01 ya armada: `POST /rest/user/login` con cuerpo `{"email":"' OR 1=1--","password":"x"}`. Las pestañas 2 y 3 quedan con PoC-02 y PoC-03 para el bloque 5.
   - Kibana: Discover con la búsqueda `DET-01-SQLi` y rango «Last 15 minutes»; otra pestaña con el dashboard `WAF - Blue Team`.
   - GitHub: el repo en `docs/` y la pestaña Actions.
   - Terminal en `waf-siem/`.
6. Tener el reloj a la vista: en la demo se dice la hora de cada ataque en voz alta.

## 1. Introducción · 0:00–1:00

- El equipo y quién hizo qué: Equipo rojo (reconocimiento, PoC en Burp y ZAP, CVSS), Equipo azul (WAF, Filebeat, Kibana, reglas, exclusiones) y todo el grupo (modelo de amenazas, pipeline, correcciones). Digan quién hizo cada parte.
- La app: OWASP Juice Shop, una tienda hecha vulnerable a propósito. El objetivo: llevarla de insegura a defendida, todo local con Docker Compose (Juice Shop, WAF con ModSecurity + OWASP CRS, Elasticsearch, Kibana y Filebeat). Solo el WAF publica puerto, en `127.0.0.1:8080`.

## 2. Diseño seguro · Hito 1 · 1:00–4:00

- **PASTA 1–5 ligado al negocio.** Abrir `docs/hito-1/01-PASTA-1-2.md`: los cinco objetivos de negocio (ON-01 a ON-05). Luego `02b-Diagramas-por-objetivo.md` y mostrar ON-02 (cuentas): ahí están el login, la amenaza T-07, V-02 y PoC-01, que es lo que se va a atacar en la demo.
- **STRIDE.** `03-PASTA-4-STRIDE.md`: 16 amenazas, las seis categorías. Señalar T-07 (manipular la consulta SQL con la entrada del usuario).
- **PASTA V y el DAST.** `03b-PASTA-5-Vulnerabilidades.md`: 10 debilidades encontradas leyendo el código. Relación con el DAST: abrir `docs/trazabilidad-y-riesgo-residual.md`, tabla «Lo que encontró el DAST». ZAP solo vio configuración (CSP ausente, CORS `*`) y no vio la inyección porque el spider no descubre la API de una SPA; por eso la inyección se confirmó a mano.
- **DFD.** `02-PASTA-3-DFD.md`: señalar LC-01 (navegador ↔ WAF), que es por donde entra todo dato no confiable, incluido el `email` del login; y LC-03 (API ↔ SQLite), donde ese dato se vuelve SQL.
- **Requisitos y casos de abuso.** `04-Requisitos-y-casos-de-abuso.md`: la tabla «Control que comprueba cada requisito» y leer RS-03 (parametrizar SQL → DET-01 + WAF + Semgrep). Hay 12 casos de abuso; leer **CA-03, inyección SQL en búsqueda** (RS-03): es la misma debilidad de concatenación que está en el login (V-02), que es lo que ataca la demo.

## 3. Pipeline de seguridad · Hito 2 · 4:00–6:00

- GitHub Actions: abrir una corrida de `DevSecOps` sobre un push. Mostrar los cuatro jobs: Semgrep (SAST), npm audit (SCA), ZAP baseline (DAST) y Syft (SBOM), y el artefacto `sbom.cdx.json` en CycloneDX.
- **El gate:** umbrales de la tabla de `docs/hito-2/README.md` (0 ERROR en Semgrep, 0 high/critical en npm audit, 0 alertas altas en ZAP). Por qué en `reporte`: Juice Shop es vulnerable a propósito y con 19 dependencias high/critical de línea base cada push saldría rojo.
- **Ejemplo de build frenado:** abrir la corrida manual con `gate: bloqueo`, en rojo. Entrar al paso `Semgrep (gate)` o `Auditoría (gate)` y leer por qué falló.

## 4. Demo completa · PoC-01 · 6:00–13:00

### Ataque (Equipo rojo)

1. En la tienda, iniciar sesión normal con `jim@juice-sh.op` / `ncc-1701`: entra bien. Cerrar sesión.
2. En Burp Repeater (pestaña 1), mandar PoC-01 con el WAF en `DetectionOnly`: `POST /rest/user/login` con `{"email":"' OR 1=1--","password":"x"}`. Decir la hora. Respuesta **200** con `authentication.token`: se entra como `admin@juice-sh.op` sin saber la contraseña. (Pegar el token en jwt.io para mostrar que el rol es admin es opcional.)
3. Explicar el payload: el `email` se concatena al SQL como `WHERE email = '' OR 1=1--'`. El `' OR 1=1` hace la condición siempre verdadera y `--` comenta el chequeo de la contraseña, así que devuelve el primer usuario (admin).
4. Clasificación: **OWASP A05:2025 Injection · CWE-89 · CVSS v3.1 9.8 (Crítica)**, `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`. Remoto, un payload fijo, sin cuenta ni interacción, y da la sesión de administrador: lectura, modificación y borrado de los datos de la tienda (C:H/I:H/A:H).

### Detección (Equipo azul)

1. Kibana, Discover, búsqueda guardada `DET-01-SQLi`: aparece el evento. Mostrar `@timestamp` (UTC: restar 6 horas para la hora de Guatemala y comparar con la que se dijo), `ruleId` 942100 y el campo `data`: `Matched Data: s&1c found within ARGS:json.email: ' OR 1=1--`.
2. Abrir el documento y señalar `fields.fuente: waf-audit`: viene del log de auditoría del WAF, que Filebeat lee y manda a Elasticsearch.
3. Dashboard `WAF - Blue Team`: el pico en el tiempo, `/rest/user/login` arriba en rutas atacadas y 942100 en reglas.

### Bloqueo (Equipo azul)

1. Terminal: `./scripts/modo-waf.sh On`.
2. Burp: el mismo PoC-01 → **403** del WAF. Decir la hora y mostrar el evento nuevo en Kibana.
3. Iniciar sesión normal en la tienda con `jim@juice-sh.op` → sigue funcionando.
4. **Exclusiones y falsos positivos.** Explicar que con el WAF en `On` se usó la tienda como cliente normal y cuatro acciones legítimas se bloqueaban (tabla en `docs/hito-3/README.md`). Mostrar uno en vivo:
   ```bash
   ./scripts/alternar-exclusiones.sh off
   ```
   En la tienda, escribir la reseña «Muy rico; echo de menos la presentación en vidrio» → falla. `./scripts/ver-bloqueos.sh 8` muestra la línea `PUT /rest/products/.../reviews` con la regla 932235 y el campo `json.message`. Seguramente también salgan `POST /socket.io/` con 920420: es el otro falso positivo, las notificaciones del navegador, y se puede señalar de paso.
   ```bash
   ./scripts/alternar-exclusiones.sh on
   ```
   Mandar la misma reseña → se publica. La exclusión solo quita ese campo de esa regla en las rutas de reseñas; `q=jugo; uname -a` en la búsqueda sigue dando 403 (mostrarlo en Burp).

### Corrección (todo el grupo)

En este video solo se anuncia: con el WAF en `On` el ataque se frena, pero el código sigue siendo vulnerable. Si el WAF vuelve a `DetectionOnly` o alguien encuentra una variante que el CRS no reconoce, PoC-01 vuelve a funcionar. La corrección en el código (login con parámetros enlazados, `$email` y `$password`), su prueba de regresión y la re-prueba en `DetectionOnly` son el Hito 4.

## 5. Resto de hallazgos y Purple Team · 13:00–15:30

- **Los otros PoC** (tabla del H2):
  - PoC-02, UNION SQLi en la búsqueda (pestaña 2 de Burp): el `q=qwert')) UNION SELECT ... FROM Users--` devuelve los correos y hashes de todos los usuarios metidos entre los productos. CVSS 7.5. El WAF también lo bloquea en `On` (DET-01, reglas 942100/942190/942270).
  - PoC-03, IDOR (pestaña 3): con el token de jim, `GET /rest/basket/1` devuelve el carrito de otro usuario. CVSS 6.5. Mostrarlo en Burp **con el WAF en `On`: sigue dando 200**. Es la prueba de que el WAF no basta.
- **Las reglas de Kibana:** DET-01 a DET-05 (las tres mínimas y dos más). Abrir DET-04 (`package.json.bak` por byte nulo) y DET-05 (inyección de comandos).
- **Purple Team:** el mismo PoC con los mismos datos de prueba, repetido con el script:
  ```bash
  ./scripts/poc-redteam.sh
  ```
  Comparar las horas que imprime con las del 17 de noviembre en `docs/hito-3/poc-On.txt` y con los eventos en Kibana: mismo payload, mismas reglas (942100 en el login; 942100/942190/942270 en la búsqueda), mismo 403. La detección se repite.

## 6. Cierre · 15:30–17:30

- **Matriz de trazabilidad:** `docs/trazabilidad-y-riesgo-residual.md`. Seguir la fila de PoC-01 de izquierda a derecha: RS-03 → T-07 → V-02 → PoC-01 → DET-01 (942100) → 403 en el WAF → Corrección 1.
- **Riesgo residual (PASTA VII):** misma página, tabla final. Lo más importante, dicho de frente: el IDOR sigue abierto hasta el H4 porque el WAF no lo ve; las inyecciones están frenadas por el WAF, pero el código sigue vulnerable; y los respaldos de `/ftp` con byte nulo (`coupons_2013.md.bak`) pasan el WAF en paranoia 1.
- **Lecciones aprendidas** (escojan 2 o 3 y cuéntenlas con sus palabras):
  - El WAF da visibilidad y tiempo, no una corrección. Lo que no se ve como ataque, como el IDOR, solo se arregla en el código.
  - Ajustar el WAF es parte del trabajo: sin las exclusiones, la tienda no funcionaba (notificaciones, reseñas, métodos REST). Cada exclusión tiene que ser lo más pequeña posible y quedar escrita.
  - El escaneo automático no encontró lo grave. ZAP vio cabeceras; las inyecciones y el IDOR salieron de leer el código (PASTA V) y probar a mano.

Al terminar: `./scripts/modo-waf.sh On` y revisar que las exclusiones queden prendidas (`./scripts/alternar-exclusiones.sh on`).
