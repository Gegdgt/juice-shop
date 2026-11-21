# Registro de uso de IA · Hito 4

Según la guía de la UVG: herramienta, prompt, respuesta y qué cambió el grupo.

## Herramienta

- **Claude Opus 5.5** (Anthropic), en la app de Claude, con acceso a la carpeta del repositorio.
- Fecha: 20 de noviembre de 2026.
- La IA leyó el código y la documentación del repo, escribió las pruebas, el código y los textos, y corrió las pruebas en su propio entorno (Node 22, base de datos en memoria). No hizo `push` ni commits en el repositorio del grupo.

## Prompt

El pedido fue uno solo, en lenguaje natural, para las tres correcciones del H4 y los ajustes del H1 y H3:

```
Hola! De este proyecto nos estaban haciendo ciertos comentarios u observaciones para
terminar este proyecto. Para empezar, me estaban diciendo que deberiamos tener un
diagrama para cada objetivo de negocio. [...] Lo segundo es que en la parte de la
defensa del hito 3, tenemos que hacer mas de las 3 que nos ponen aqui. Tenemos que
hacer otras dos mas de las reglas y exclusiones.

Por ultimo tenemos que hacer el hito 4 para ya dejarlo todo listo y entregar el video
```

Contexto que la IA tomó del repositorio (no se le pegó en el chat):

- `docs/hito-4/README.md`: la plantilla del curso (al menos dos vulnerabilidades del Equipo rojo, corrección en el código, prueba de regresión, auditoría, re-prueba en `DetectionOnly`).
- `docs/hito-2/README.md`: PoC-01 (SQLi en el login), PoC-02 (UNION SQLi en la búsqueda) y PoC-03 (IDOR en el carrito).
- `docs/hito-1/03b-PASTA-5-Vulnerabilidades.md`: V-01, V-02 y V-03 con archivo y línea.
- `routes/login.ts`, `routes/search.ts`, `routes/basket.ts` y sus pruebas en `test/api/`.
- `data/static/codefixes/*_correct.ts`: la corrección de referencia del propio Juice Shop.

## Respuesta de la IA

### Cómo propuso trabajar

1. Escribir primero una prueba que repite cada PoC contra la API y comprobar que falla con el código vulnerable (9 de 14 fallan; los 5 casos legítimos pasan).
2. Corregir cada vulnerabilidad en su propio commit.
3. Correr de nuevo la prueba nueva y toda la suite de la API para ver qué más se rompía.
4. Pasar Semgrep sobre los archivos cambiados, antes y después.

### Corrección 1 · `routes/login.ts` (PoC-01)

```diff
diff --git a/routes/login.ts b/routes/login.ts
index fb9fce357..551d1b870 100644
--- a/routes/login.ts
+++ b/routes/login.ts
@@ -31,7 +31,12 @@ export function login () {
 
   return (req: Request, res: Response, next: NextFunction) => {
     verifyPreLoginChallenges(req) // vuln-code-snippet hide-line
-    models.sequelize.query(`SELECT * FROM Users WHERE email = '${req.body.email || ''}' AND password = '${security.hash(req.body.password || '')}' AND deletedAt IS NULL`, { model: UserModel, plain: true }) // vuln-code-snippet vuln-line loginAdminChallenge loginBenderChallenge loginJimChallenge
+    // H4 Corrección 1 (PoC-01, CWE-89): el email y el hash van como parámetros enlazados,
+    // nunca concatenados al SQL. Si no llegan como texto, se tratan como vacíos (401).
+    const email = typeof req.body.email === 'string' ? req.body.email : ''
+    const password = typeof req.body.password === 'string' ? req.body.password : ''
+    models.sequelize.query('SELECT * FROM Users WHERE email = $email AND password = $password AND deletedAt IS NULL', // vuln-code-snippet vuln-line loginAdminChallenge loginBenderChallenge loginJimChallenge
+      { bind: { email, password: security.hash(password) }, model: UserModel, plain: true })
       .then((authenticatedUser) => { // vuln-code-snippet neutral-line loginAdminChallenge loginBenderChallenge loginJimChallenge
         const user = utils.queryResultToJson(authenticatedUser)
         if (user.data?.id && user.data.totpSecret !== '') {
```

### Corrección 2 · `routes/search.ts` (PoC-02)

```diff
diff --git a/routes/search.ts b/routes/search.ts
index 52e1a60a3..22d5fb851 100644
--- a/routes/search.ts
+++ b/routes/search.ts
@@ -18,9 +18,13 @@ class ErrorWithParent extends Error {
 // vuln-code-snippet start unionSqlInjectionChallenge dbSchemaChallenge
 export function searchProducts () {
   return (req: Request, res: Response, next: NextFunction) => {
-    let criteria: any = req.query.q === 'undefined' ? '' : req.query.q ?? ''
-    criteria = (criteria.length <= 200) ? criteria : criteria.substring(0, 200)
-    models.sequelize.query(`SELECT * FROM Products WHERE ((name LIKE '%${criteria}%' OR description LIKE '%${criteria}%') AND deletedAt IS NULL) ORDER BY name`) // vuln-code-snippet vuln-line unionSqlInjectionChallenge dbSchemaChallenge
+    // H4 Corrección 2 (PoC-02, CWE-89): q siempre es texto y va como replacement de
+    // Sequelize. Las comillas y paréntesis del usuario ya no pueden cerrar la consulta.
+    const raw = Array.isArray(req.query.q) ? req.query.q[0] : req.query.q
+    let criteria: string = typeof raw === 'string' && raw !== 'undefined' ? raw : ''
+    criteria = criteria.substring(0, 200)
+    models.sequelize.query('SELECT * FROM Products WHERE ((name LIKE :criteria OR description LIKE :criteria) AND deletedAt IS NULL) ORDER BY name', // vuln-code-snippet vuln-line unionSqlInjectionChallenge dbSchemaChallenge
+      { replacements: { criteria: `%${criteria}%` } })
       .then(([products]: any) => {
         const dataString = JSON.stringify(products)
         if (challengeUtils.notSolved(challenges.unionSqlInjectionChallenge)) { // vuln-code-snippet hide-start
```

### Corrección 3 · `routes/basket.ts` (PoC-03)

```diff
diff --git a/routes/basket.ts b/routes/basket.ts
index 18dd06914..aee99eedc 100644
--- a/routes/basket.ts
+++ b/routes/basket.ts
@@ -16,7 +16,18 @@ export function retrieveBasket () {
   return async (req: Request, res: Response, next: NextFunction) => {
     try {
       const id = req.params.id
-      const basket = await BasketModel.findOne({ where: { id }, include: [{ model: ProductModel, paranoid: false, as: 'Products' }] })
+      // H4 Corrección 3 (PoC-03, CWE-639): el carrito se busca por id Y por el dueño de
+      // la sesión. Un id ajeno o inexistente responde 403, sin datos y sin distinguirlos.
+      const sessionUser = security.authenticatedUsers.from(req)
+      if (!sessionUser?.data?.id) {
+        res.status(401).json({ status: 'error', message: 'Unauthorized' })
+        return
+      }
+      const basket = await BasketModel.findOne({ where: { id, UserId: sessionUser.data.id }, include: [{ model: ProductModel, paranoid: false, as: 'Products' }] })
+      if (basket == null) {
+        res.status(403).json({ status: 'error', message: 'Forbidden' })
+        return
+      }
       /* jshint eqeqeq:false */
       challengeUtils.solveIf(challenges.basketAccessChallenge, () => {
         const user = security.authenticatedUsers.from(req)
```

### Qué se aceptó y qué se descartó

| Propuesta o alternativa | Decisión | Por qué |
|---|---|---|
| Parámetros enlazados (`bind`) en el login y `replacements` en la búsqueda | Aceptado | Es la forma de Sequelize de hacer una consulta preparada. Coincide con la corrección de referencia de Juice Shop (`loginAdminChallenge_4_correct.ts`, `unionSqlInjectionChallenge_2_correct.ts`). |
| Revisar el tipo de `email`, `password` y `q` antes de la consulta | Aceptado (va más allá de la referencia) | La referencia no lo hace. Un JSON con `{"email": {...}}` o un `q` repetido llegarían como objeto o arreglo; ahora se tratan como texto o como vacío y no producen un 500. |
| Escapar comillas o filtrar palabras como `UNION` | Descartado | Es una lista negra; el propio Juice Shop la pone como respuesta incorrecta (`loginAdminChallenge_1.ts`). |
| Comparar el id pedido con el `bid` guardado al iniciar sesión | Descartado | El `bid` vive en memoria junto al token; buscar por `UserId` en la misma consulta deja la regla en la base de datos y no depende de ese mapa. |
| Responder 404 para un carrito ajeno | Descartado, se usó 403 | RS-02 acepta 403 o 404. Con 403 la re-prueba se lee mejor, y como un id inexistente también da 403, no se puede usar para saber qué carritos existen. |
| Borrar los marcadores `vuln-code-snippet` | Descartado | Los usan los retos de código del scoreboard y sus pruebas. Se dejaron en la línea corregida. |
| Pruebas originales que comprobaban la vulnerabilidad (por ejemplo «GET existing basket of another user» con 200) | Se invirtieron | 18 pruebas de `login` (5), `search` (9) y `basket` (4) esperaban que el ataque funcionara. Ahora esperan el comportamiento seguro y llevan el prefijo `H4 ·` en el nombre. La pista de línea de `vuln-code-snippet.test.ts` pasó de la 15 a la 19 porque el login ganó cuatro líneas antes de la consulta. |

## Qué cambió el grupo

Ajustes que salieron al correr las pruebas, antes de dar el código por bueno:

- ESLint marcó un import sin uso (`security`) en `test/api/search.test.ts` después de invertir las pruebas; se quitó.
- La suite completa de la API mostró los 18 casos que comprobaban la vulnerabilidad y la pista de línea del reto de código (ver tabla de arriba). Ninguna otra prueba se rompió: las 27 que fallan en el entorno de la IA también fallan sin los cambios, porque ese entorno no tiene el frontend compilado ni salida a internet.

Revisión de Sebas antes de hacer los commits (marcar al revisar):

- [ ] Leí los tres diffs completos.
- [ ] Corrí `test/api/h4-regression.test.ts` en mi máquina y pasa.
- [ ] Corrí la re-prueba con el WAF en `DetectionOnly` (`waf-siem/scripts/reprueba-h4.sh`).
- [ ] Cambios propios (si hubo):
