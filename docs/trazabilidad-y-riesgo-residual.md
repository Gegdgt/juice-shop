# Matriz de trazabilidad y riesgo residual (PASTA VI y VII)

Une los cuatro hitos en una sola tabla: de cada requisito a la amenaza que cubre, el PoC que la confirmó, la regla que la detecta, lo que hace el WAF y la corrección en el código. Después, lo que sigue expuesto y por qué.

Fuentes: [requisitos y casos de abuso](hito-1/04-Requisitos-y-casos-de-abuso.md), [STRIDE](hito-1/03-PASTA-4-STRIDE.md), [PASTA V](hito-1/03b-PASTA-5-Vulnerabilidades.md), [Hito 2](hito-2/README.md), [Hito 3](hito-3/README.md) y [Hito 4](hito-4/README.md).

## Matriz de trazabilidad

| Requisito | Amenaza | Caso de abuso | Debilidad | PoC / ataque (H2) | Regla en Kibana (H3) | Control en el WAF (H3) | Corrección (H4) |
|---|---|---|---|---|---|---|---|
| RS-03 Parametrizar SQL | T-07 | CA-03 | V-01 `routes/search.ts` | **PoC-02** UNION SQLi en la búsqueda · A05 · CWE-89 · CVSS 7.5 | DET-01 (942100, 942190, 942270) | `On`: 403. Sin exclusiones en `q` | Corrección 2: `replacements` de Sequelize |
| RS-03 Parametrizar SQL | T-07, T-05 | CA-03 (misma técnica) | V-02 `routes/login.ts` | **PoC-01** SQLi en el login · A05 · CWE-89 · CVSS 9.8 | DET-01 (942100) | `On`: 403 | Corrección 1: parámetros enlazados |
| RS-02 Autorizar por dueño | T-06, T-10 | CA-02 | V-03 `routes/basket.ts` | **PoC-03** IDOR en el carrito · A01 · CWE-639 · CVSS 6.5 | Ninguna: el WAF no la ve | 200 en `DetectionOnly` y en `On` | Corrección 3: `where id + UserId` |
| RS-04 Codificar por contexto | T-08 | CA-04 | V-04, V-06 | `<script>alert(1)</script>` en `q` (prueba de detección) | DET-02 (941100, 941110, 941160, 941390) | `On`: 403 | No corregido. V-06 no pasa por el WAF |
| RS-05 Limitar abuso | T-03 | CA-05 | — | `PROPFIND` (escaneo de métodos) | DET-03 (911100) | `On`: 403. Exclusión tipo 4: `PUT PATCH DELETE` permitidos | No aplica (límite de tasa pendiente) |
| RS-02 Autorizar lecturas | T-10, T-12 | — | V-10 listado de `/ftp` | `package.json.bak%2500.md` (byte nulo) | DET-04 (930130) | `On`: 403. `coupons_2013.md.bak%2500.md` pasa | No corregido |
| RS-03 Validar entradas | Reconocimiento del Equipo rojo | — | — | `q=jugo; uname -a`, `q=$(id)` | DET-05 (932235, 932260, 932130) | `On`: 403 | No aplica: `q` no llega a una shell |
| RS-08 Solo el WAF publica | T-14 | CA-10 | — | Acceso directo al puerto 3000 | — | La app usa `expose`, sin `ports` | No aplica |

### Exclusiones (falsos positivos documentados)

| ID | Regla | Dónde | Acción legítima que se bloqueaba |
|---|---|---|---|
| Tipo 4 (`.env`) | 911100 | `PUT`, `PATCH`, `DELETE` en la API | Cambiar cantidades, quitar productos, editar reseñas |
| 10002 | 932260 | `REQUEST_FILENAME` en `/rest/user/whoami` | La SPA pregunta quién está logueado en cada carga |
| 10003 | 920420 | `POST /socket.io/` con `text/plain` | Notificaciones en tiempo real |
| 10004 | 932235 | `ARGS:json.message` en reseñas | Reseña «Muy rico; echo de menos…» |

## Lo que encontró el DAST y dónde cae en PASTA

El ZAP baseline del Equipo rojo ([`reporte-zap-redteam.html`](hito-2/reporte-zap-redteam.html)) solo encontró problemas de configuración. Las inyecciones y el IDOR no aparecen porque el spider no descubre la API de una SPA en Angular; por eso se confirmaron a mano con Burp.

| Alerta de ZAP | Riesgo · CWE | Amenaza y requisito en PASTA |
|---|---|---|
| Cabecera Content-Security-Policy no configurada | Medio · CWE-693 | T-08 / RS-04: sin CSP, un XSS como V-06 no tiene una segunda barrera |
| Configuración incorrecta cross-domain (CORS `*`) | Medio · CWE-264 | T-10 / RS-02: cualquier origen puede leer las respuestas de la API |
| Aplicación web moderna | Informativo | Explica por qué el escaneo automático no ve la API y hace falta la prueba manual |

## PASTA VI · Análisis de ataques

Los tres PoC del H2 son la etapa VI: cada uno se ejecutó por el WAF, con payload, hora y CVSS v3.1 justificado métrica por métrica. El orden de prioridad que sale de ahí es el que siguió el proyecto: PoC-01 (9.8) y PoC-02 (7.5) se detectan y bloquean en el WAF desde el H3 y se corrigen en el H4; PoC-03 (6.5) no tiene control en el WAF, así que su única defensa es la corrección en el código.

## PASTA VII · Riesgo residual

Estado con los controles del H3 (WAF en `On`, reglas en Kibana) y antes de integrar las correcciones del H4.

| Riesgo | Qué sigue expuesto | Por qué | Nivel | Qué lo cierra |
|---|---|---|---|---|
| IDOR en el carrito (PoC-03) | Cualquier cliente lee el carrito de otro cambiando el id | Es una petición válida; el WAF no sabe de quién es cada carrito | Alto | Corrección 3 (H4) |
| SQLi en login y búsqueda (PoC-01, PoC-02) | El código sigue siendo vulnerable detrás del WAF | El WAF bloquea los payloads que reconoce. Si queda en `DetectionOnly`, se apaga o alguien encuentra una variante que el CRS no conoce, el ataque funciona | Medio mientras el WAF esté en `On` | Correcciones 1 y 2 (H4) |
| Respaldos de `/ftp` por byte nulo | `coupons_2013.md.bak` y otros respaldos se descargan | En paranoia 1 el CRS solo reconoce nombres como `package.json` | Medio | Corregir `routes/fileServer.ts` o una regla propia para `%00` |
| XSS en el DOM (V-06) | Un enlace con payload en el fragmento ejecuta código en el navegador | El fragmento de la URL nunca llega al servidor; sin CSP (ZAP) no hay segunda barrera | Medio | Codificar en el frontend y agregar CSP |
| Sesiones y contraseñas (V-07, V-08, V-09) | MD5 sin sal, clave del JWT en el código, tokens de 6 horas | Decisión de laboratorio; no se tocaron | Medio | Hash con sal (bcrypt/argon2), clave fuera del código, expiración corta |
| Sin límite de intentos ni de tasa (RS-01, RS-05) | Fuerza bruta y ráfagas | El CRS no limita la tasa | Medio | Límite en la app o en el proxy |
| Checkout y cupón con el mismo patrón que el IDOR | Comprar o aplicar cupón sobre un carrito ajeno | La corrección 3 solo cubre `GET /rest/basket/:id` | Medio | Misma verificación de dueño en esas rutas |
| Exclusiones del WAF | 4 huecos acotados (tabla de arriba) | Riesgo aceptado para que la tienda funcione | Bajo | Revisarlas si cambian las rutas |
| Trazabilidad de negocio (T-13) | Quién vio o cambió qué carrito no queda en el SIEM | La app no escribe logs a `app-logs/` | Medio | Logs de auditoría de la app hacia Filebeat |
