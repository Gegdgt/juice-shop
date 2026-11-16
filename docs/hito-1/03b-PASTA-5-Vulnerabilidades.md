# PASTA V — Análisis de vulnerabilidades

La etapa V baja las amenazas de la [etapa IV](03-PASTA-4-STRIDE.md) a debilidades concretas del código. Son **debilidades identificadas por lectura del código del fork** (caja blanca); ninguna se explotó en H1. Las que el Red Team convierta en PoC se confirman en H2 con ZAP y Burp, a través del WAF, y ahí se les calcula el CVSS (etapa VI).

La guía del curso pide reutilizar aquí los hallazgos del Proyecto DAST. Ese proyecto se hizo sobre otra aplicación, así que esta etapa parte del código de Juice Shop en el commit base del fork (`266448aba`).

## Debilidades identificadas

| ID | Debilidad | Dónde | CWE · OWASP Top 10:2025 | Amenaza | Relación con el DFD | Activa en Docker |
|---|---|---|---|---|---|---|
| V-01 | La búsqueda arma el SQL concatenando el parámetro `q` | `routes/search.ts:23` | CWE-89 · A05 Injection | T-07 | F03/F04, cruce LC-03 (P2 → D1) | Sí |
| V-02 | El login arma el SQL concatenando `email`; permite entrar sin contraseña | `routes/login.ts:34` | CWE-89 · A05 Injection | T-07 | F03/F04, cruce LC-03 (P2 → D1) | Sí |
| V-03 | El carrito se devuelve por `id` sin compararlo con el dueño de la sesión | `routes/basket.ts:19` | CWE-639 · A01 Broken Access Control | T-06, T-10 | Entra por F01/F02 y lee D1 por F03/F04 | Sí |
| V-04 | El identificador de orden entra en un `$where` concatenado y vuelve al navegador, que lo pinta como HTML | `routes/trackOrder.ts:15,18`; `frontend/src/app/track-result/track-result.component.ts:49` | CWE-943 y CWE-79 · A05 Injection | T-16, T-08 | F08/F09 (LC-03) y F05/F06 (LC-01) | No: el modo seguro limpia el `id` (línea 15). Solo con `NODE_ENV=unsafe` |
| V-05 | Las reseñas se consultan con un `$where` concatenado | `routes/showProductReviews.ts:31,36` | CWE-943 · A05 Injection | T-16 | F08/F09, cruce LC-03 (P2 → D2) | No: el modo seguro convierte el `id` a número (línea 31) |
| V-06 | XSS en el DOM: el término de búsqueda se marca como HTML confiable | `frontend/src/app/search-result/search-result.component.ts:146` | CWE-79 · A05 Injection | T-08 | Solo A1: el valor viaja en el fragmento de la URL y no cruza LC-01 | Sí |
| V-07 | Contraseñas guardadas con MD5 sin sal | `lib/insecurity.ts:41` | CWE-916 · A04 Cryptographic Failures | T-05, T-07 | D1; agrava lo que exponga V-01 | Sí |
| V-08 | La clave privada RSA que firma los JWT está escrita en el código | `lib/insecurity.ts:21` | CWE-321 · A04 Cryptographic Failures | T-01 | Sesión sobre F01/F02 | Sí |
| V-09 | Los JWT valen 6 horas; la revocación al cerrar sesión está por comprobar | `lib/insecurity.ts:54` | CWE-613 · A07 Authentication Failures | T-01 | Sesión sobre F01/F02 | Sí |
| V-10 | Listado de directorios en `/ftp`, `/encryptionkeys` y `/support/logs` | `server.ts:294,302,306` | CWE-548 · A02 Security Misconfiguration | T-10, T-12 | F05/F06, cruce LC-01 | Sí |

«Activa en Docker» sale de `data/static/challenges.yml` (campo `disabledEnv`) y de `lib/utils.ts:192–224`: con `safetyMode: auto`, la imagen desactiva los retos marcados para Docker. `config/unsafe.yml` los vuelve a activar si el contenedor arranca con `NODE_ENV=unsafe`.

## Qué implica para H2 y H3

- **Candidatos a PoC con la imagen tal cual:** V-01, V-02 y V-03, más V-10 como hallazgo de configuración.
- **XSS que el WAF pueda ver:** el único que llega al servidor es V-04, y exige levantar Juice Shop con `NODE_ENV=unsafe`. Es una decisión del grupo: ese modo también activa retos de XXE y RCE dentro del contenedor.
- **V-06 no pasa por el WAF.** El payload va después del `#` y nunca sale del navegador, así que ni ModSecurity ni Kibana lo registran. Sirve como hallazgo, no como base de una regla de detección.
- **V-03 es una petición válida para el CRS.** El WAF no distingue un ID ajeno de uno propio; se demuestra con el PoC y se corrige en el código (H4).

Los requisitos que cubren estas debilidades y el control que los comprueba están en [requisitos y casos de abuso](04-Requisitos-y-casos-de-abuso.md).
