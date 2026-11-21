# Hito 4 · Remediación con IA

Se corrigieron en el código las tres vulnerabilidades del Equipo rojo (H2): las dos inyecciones SQL y el IDOR. El IDOR era la que más importaba, porque el WAF no la puede ver (H3). Cada corrección va en su propio commit, después de un commit que solo agrega la prueba de regresión, para que el historial muestre la prueba fallando primero.

| Commit | Qué hace |
|---|---|
| `test(h4): pruebas de regresión para PoC-01, PoC-02 y PoC-03` | Agrega [`test/api/h4-regression.test.ts`](../../test/api/h4-regression.test.ts). Con el código de ese commit fallan 9 de 14 |
| `fix(h4): login con parámetros enlazados (PoC-01, CWE-89)` | Corrección 1 |
| `fix(h4): búsqueda con replacements de Sequelize (PoC-02, CWE-89)` | Corrección 2 |
| `fix(h4): el carrito solo se entrega a su dueño (PoC-03, CWE-639)` | Corrección 3 |
| `feat(h4): compose del H4 y re-prueba del Equipo rojo` | `waf-siem/docker-compose.h4.yml` y `waf-siem/scripts/reprueba-h4.sh` |

Uso de IA (herramienta, prompt completo, respuesta, qué se aceptó y qué se descartó): [`ia/registro-ia.md`](ia/registro-ia.md). Es el mismo registro para las tres correcciones porque salieron del mismo pedido.

**Cómo se prueba todo, desde la raíz del repo:**

```bash
# Prueba de regresión (API con base de datos en memoria, no necesita Docker)
node --import ./test/api/helpers/test-env.mjs --import tsx --test --test-force-exit test/api/h4-regression.test.ts

# Re-prueba del Equipo rojo por el WAF en DetectionOnly, con la app construida desde este código
cd waf-siem
export COMPOSE_FILE=docker-compose.yml:docker-compose.h4.yml
docker compose up -d --build app          # la primera vez tarda: compila backend y frontend
./scripts/modo-waf.sh DetectionOnly
./scripts/reprueba-h4.sh | tee ../docs/hito-4/reprueba-DetectionOnly.txt
```

## Corrección 1 · SQLi en el login

- Vulnerabilidad (enlace al PoC del Hito 2): [PoC-01 · SQLi en el login](../hito-2/README.md#poc-01--sqli-en-el-login-cwe-89) (V-02, CWE-89, CVSS 9.8).
- Commit: `fix(h4): login con parámetros enlazados (PoC-01, CWE-89)`.
- Herramienta de IA: Claude Opus 5.5 (Anthropic).

### Prompt

```
Ver ia/registro-ia.md: un solo pedido para el H4 completo ("tenemos que hacer el hito 4
para ya dejarlo todo listo"). La IA tomó el PoC-01 de docs/hito-2/README.md, la línea
vulnerable de docs/hito-1/03b-PASTA-5-Vulnerabilidades.md (V-02, routes/login.ts:34) y
la corrección de referencia de data/static/codefixes/loginAdminChallenge_4_correct.ts.
```

### Respuesta de la IA

Diff completo en [`ia/registro-ia.md`](ia/registro-ia.md#corrección-1--routeslogints-poc-01). La consulta deja de armarse con `${req.body.email}`:

```ts
const email = typeof req.body.email === 'string' ? req.body.email : ''
const password = typeof req.body.password === 'string' ? req.body.password : ''
models.sequelize.query('SELECT * FROM Users WHERE email = $email AND password = $password AND deletedAt IS NULL',
  { bind: { email, password: security.hash(password) }, model: UserModel, plain: true })
```

- Aceptado: parámetros enlazados (`bind`), igual que la referencia de Juice Shop.
- Aceptado, más allá de la referencia: si `email` o `password` no llegan como texto se tratan como vacíos (401 en lugar de un error 500).
- Descartado: escapar comillas o filtrar palabras SQL (lista negra).

### Qué cambió el grupo

Ver [`ia/registro-ia.md`](ia/registro-ia.md#qué-cambió-el-grupo). En esta corrección: las 5 pruebas originales de `test/api/login.test.ts` que esperaban entrar con `' or 1=1--` ahora esperan 401, y la pista de línea del reto de código pasó de la 15 a la 19.

### Prueba de regresión

- Prueba (nombre y comando): bloque `H4 Corrección 1 · PoC-01 SQLi en el login (CWE-89)` de `test/api/h4-regression.test.ts`, con el comando de arriba. Seis casos: `' OR 1=1--`, `admin@juice-sh.op'--`, `' UNION SELECT * FROM Users--`, email como objeto, login legítimo de jim y cuenta con 2FA.
- Falla antes de la corrección: sí, los 4 ataques dan 200 con token; solo pasan los 2 casos legítimos ([`regresion-antes.txt`](regresion-antes.txt)).
- Pasa después: sí, 6 de 6 ([`regresion-despues.txt`](regresion-despues.txt)).

### Auditoría del código generado

- [ ] SAST del pipeline corrido sobre este código, sin excluirlo. Resultado: en local, Semgrep con las reglas comunitarias de JavaScript y TypeScript pasa de 3 hallazgos en `routes/login.ts:34` (`express-sequelize-injection`, `tainted-sql-string`, `sequelize-raw-query`) a 0 ([`sast-local.txt`](sast-local.txt)). Pipeline en GitHub, después del push: `DevSecOps #__`.
- [ ] Revisión manual con la checklist de la Lectura 10. Revisión preliminar (falta contrastarla con la checklist de la lectura). Hallazgos: la entrada se valida por tipo antes de usarse; la consulta no concatena nada del usuario; los errores siguen yendo a `next(error)` sin cambiar el mensaje; no se tocó la autorización ni el manejo del JWT. Sigue abierto (fuera de esta corrección): contraseñas en MD5 sin sal (V-07) y sin límite de intentos (RS-01).
- [x] Cada dependencia nueva existe en el repositorio oficial (no es slopsquatting): no hay dependencias nuevas; `package.json` y `frontend/package.json` no cambian.
- [x] No se introdujeron secretos: Semgrep `generic/secrets` solo marca una contraseña de reto que ya estaba en `routes/login.ts` antes del cambio.

### Re-prueba del Equipo rojo

- Modo del WAF: `DetectionOnly`.
- Resultado esperado con `reprueba-h4.sh`: PoC-01 responde **401** sin token, y el evento sigue apareciendo en Kibana con DET-01 (el WAF lo detecta, pero ya no hace falta que lo bloquee). Salida: [`reprueba-DetectionOnly.txt`](reprueba-DetectionOnly.txt).

## Corrección 2 · UNION SQLi en la búsqueda

- Vulnerabilidad (enlace al PoC del Hito 2): [PoC-02 · UNION SQLi en la búsqueda](../hito-2/README.md#poc-02--union-sqli-en-la-búsqueda-cwe-89) (V-01, CWE-89, CVSS 7.5).
- Commit: `fix(h4): búsqueda con replacements de Sequelize (PoC-02, CWE-89)`.
- Herramienta de IA: Claude Opus 5.5 (Anthropic).

### Prompt

```
El mismo pedido (ia/registro-ia.md). Contexto: PoC-02 de docs/hito-2/README.md, V-01 en
routes/search.ts:23 y data/static/codefixes/unionSqlInjectionChallenge_2_correct.ts.
```

### Respuesta de la IA

```ts
const raw = Array.isArray(req.query.q) ? req.query.q[0] : req.query.q
let criteria: string = typeof raw === 'string' && raw !== 'undefined' ? raw : ''
criteria = criteria.substring(0, 200)
models.sequelize.query('SELECT * FROM Products WHERE ((name LIKE :criteria OR description LIKE :criteria) AND deletedAt IS NULL) ORDER BY name',
  { replacements: { criteria: `%${criteria}%` } })
```

- Aceptado: `replacements` de Sequelize, como la referencia de Juice Shop.
- Aceptado, más allá de la referencia: `q` repetido (`?q=a&q=b`) toma el primer valor y siempre es texto.
- Anotado, no cambiado: `%` y `_` escritos por el usuario siguen funcionando como comodines del `LIKE`. Cambia qué productos salen, no la consulta, así que no es inyección.

### Qué cambió el grupo

Ver [`ia/registro-ia.md`](ia/registro-ia.md#qué-cambió-el-grupo). En esta corrección: las 9 pruebas originales de `test/api/search.test.ts` que esperaban el UNION, el error SQL 500 o ver productos borrados ahora esperan una lista vacía; se quitó un import que quedó sin uso.

### Prueba de regresión

- Prueba (nombre y comando): bloque `H4 Corrección 2 · PoC-02 UNION SQLi en la búsqueda (CWE-89)`. Cinco casos: el payload exacto de PoC-02, `'))--` (antes daba error SQL 500), un producto borrado con el `WHERE` comentado, `q` repetido y la búsqueda legítima `apple`.
- Falla antes de la corrección: sí, los 3 ataques ([`regresion-antes.txt`](regresion-antes.txt)).
- Pasa después: sí, 5 de 5 ([`regresion-despues.txt`](regresion-despues.txt)).

### Auditoría del código generado

- [ ] SAST del pipeline corrido sobre este código, sin excluirlo. Resultado: en local, de 3 hallazgos en `routes/search.ts:23` a 0 ([`sast-local.txt`](sast-local.txt)). Pipeline en GitHub: `DevSecOps #__`.
- [ ] Revisión manual con la checklist de la Lectura 10. Revisión preliminar (falta contrastarla con la checklist de la lectura). Hallazgos: entrada validada por tipo y por largo (200 caracteres); la consulta queda fija; el resto de la función (traducción de nombres, retos) no cambió. El XSS en el DOM de la búsqueda (V-06) es del frontend y no se tocó.
- [x] Cada dependencia nueva existe en el repositorio oficial (no es slopsquatting): no hay dependencias nuevas.
- [x] No se introdujeron secretos.

### Re-prueba del Equipo rojo

- Modo del WAF: `DetectionOnly`.
- Resultado esperado: PoC-02 responde **200 con `data: []`**, sin correos ni hashes (el script lo revisa y lo escribe). DET-01 sigue registrando el intento. Salida: [`reprueba-DetectionOnly.txt`](reprueba-DetectionOnly.txt).

## Corrección 3 · IDOR en el carrito

- Vulnerabilidad (enlace al PoC del Hito 2): [PoC-03 · IDOR en el carrito](../hito-2/README.md#poc-03--idor-en-el-carrito-cwe-639) (V-03, CWE-639, CVSS 6.5).
- Commit: `fix(h4): el carrito solo se entrega a su dueño (PoC-03, CWE-639)`.
- Herramienta de IA: Claude Opus 5.5 (Anthropic).

### Prompt

```
El mismo pedido (ia/registro-ia.md). Contexto: PoC-03 de docs/hito-2/README.md, la nota
del H3 de que el WAF no lo ve, V-03 en routes/basket.ts:19 y el requisito RS-02
("acceso de A a recurso de B devuelve 403/404, sin datos de B").
```

### Respuesta de la IA

```ts
const sessionUser = security.authenticatedUsers.from(req)
if (!sessionUser?.data?.id) {
  res.status(401).json({ status: 'error', message: 'Unauthorized' })
  return
}
const basket = await BasketModel.findOne({ where: { id, UserId: sessionUser.data.id }, include: [...] })
if (basket == null) {
  res.status(403).json({ status: 'error', message: 'Forbidden' })
  return
}
```

- Aceptado: el dueño se comprueba en la misma consulta (`id` y `UserId` de la sesión).
- Aceptado: un id ajeno y uno inexistente responden igual (403), así no sirve para saber qué carritos existen.
- Descartado: comparar contra el `bid` guardado al iniciar sesión, y responder 404.
- Pendiente, fuera de esta corrección: `POST /rest/basket/:id/checkout` y `PUT /rest/basket/:id/coupon/:coupon` tienen el mismo patrón. El reto `basketAccessChallenge` del scoreboard ya no se puede resolver.

### Qué cambió el grupo

Ver [`ia/registro-ia.md`](ia/registro-ia.md#qué-cambió-el-grupo). En esta corrección: las 4 pruebas de `test/api/basket.test.ts` que esperaban leer el carrito de otro usuario, uno inexistente o uno con JWT falsificado ahora esperan 403 (o distinto de 200) y sin datos.

### Prueba de regresión

- Prueba (nombre y comando): bloque `H4 Corrección 3 · PoC-03 IDOR en el carrito (CWE-639)`. Tres casos: jim pide el carrito 1 (de admin), jim pide el suyo y jim pide el 4711, que no existe.
- Falla antes de la corrección: sí, el carrito ajeno y el inexistente dan 200 ([`regresion-antes.txt`](regresion-antes.txt)).
- Pasa después: sí, 3 de 3 ([`regresion-despues.txt`](regresion-despues.txt)).

### Auditoría del código generado

- [ ] SAST del pipeline corrido sobre este código, sin excluirlo. Resultado: en local, Semgrep no tenía hallazgos en `routes/basket.ts` ni antes ni después ([`sast-local.txt`](sast-local.txt)); un IDOR no se ve con análisis estático, por eso el control es la prueba de regresión (así estaba planeado en RS-02). Pipeline en GitHub: `DevSecOps #__`.
- [ ] Revisión manual con la checklist de la Lectura 10. Revisión preliminar (falta contrastarla con la checklist de la lectura). Hallazgos: sin sesión válida responde 401 antes de consultar; la autorización se hace en el servidor con la identidad del token, no con datos del cliente; la respuesta de error no trae datos del carrito.
- [x] Cada dependencia nueva existe en el repositorio oficial (no es slopsquatting): no hay dependencias nuevas.
- [x] No se introdujeron secretos.

### Re-prueba del Equipo rojo

- Modo del WAF: `DetectionOnly`.
- Resultado esperado: PoC-03 responde **403** con el JSON de la app (`{"status":"error","message":"Forbidden"}`), no con la página 403 del WAF; el carrito propio de jim sigue dando 200. Es el único de los tres que el WAF nunca vio: ahora lo detiene el código. Salida: [`reprueba-DetectionOnly.txt`](reprueba-DetectionOnly.txt).

## Suite completa

Con las correcciones, la suite de la API (`npm run test:api`) no tiene pruebas nuevas que fallen: las 18 que comprobaban las vulnerabilidades se actualizaron, y las 27 que fallan en el entorno donde se corrió (sin el frontend compilado ni salida a internet) fallan igual sin los cambios. `npm run test:server`: 339 pasan, 0 fallan.
