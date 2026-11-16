# Red Team — Reconocimiento autorizado

**Responsable:** Gegdgt. **Destino único:** `http://127.0.0.1:8081/`, autorizado por el propietario al encontrar ocupado 8080. No seguir explorando EnterpriseDB en 8080. No se hicieron escaneos públicos, fuerza bruta, explotación automática, pruebas destructivas ni modificaciones de pedidos.

## Método y fuentes

Se realizaron GET normales sin credenciales/cookies, inspección de Docker y lectura del código incluido en la imagen local. El fork ahora contiene también el código oficial en la raíz. Versión de la imagen: **20.4.0-SNAPSHOT**, fijada por digest. Fecha del inventario original: **2026-11-15, 23:52, America/Guatemala (UTC−06:00)**. Los logs del contenedor muestran UTC; la diferencia de día no es inconsistencia. La [verificación de migración](evidencias/MIGRACION.md) distingue estos resultados históricos de la ejecución desde el fork.

- **E-HTTP:** sección `http` de [verificacion-20261115-235210.json](evidencias/verificacion-20261115-235210.json), con fecha, URL, código, tipo, longitud y hash del cuerpo. No se almacenan cuerpos de sesión.
- **E-CODE:** sección `codigo.stdout` del mismo archivo, JSON con ruta, SHA-256 y líneas del código de la imagen. Es evidencia estática, no ejecución de cada endpoint.
- **E-WAF:** sección `waf`, extracto de auditoría sanitizado. [Interpretación](evidencias/VERIFICACION.md).
- **E-UI:** pendiente. El host de acceso del navegador y la conexión nativa de automatización no estuvieron disponibles; no se fabricaron capturas.

## Rutas observadas por HTTP

| ID | Función | Método / ruta | Sesión | Entradas | Datos / resultado real | Hipótesis | Fuente |
|---|---|---|---|---|---|---|---|
| REC-01 | Documento SPA | GET `/` | No enviada | URL, cabeceras normales | 200, HTML 9984 bytes, contiene Juice Shop; interfaz visual pendiente | T-08 | E-HTTP `/` |
| REC-02 | Robots | GET `/robots.txt` | No enviada | Sin parámetros | 200; declara `Disallow: /ftp`. No se visitó `/ftp`; robots no es autorización | T-10 (hipótesis de exposición) | E-HTTP robots |
| REC-03 | Búsqueda | GET `/rest/products/search?q=apple` | No enviada | `q` texto | 200; 3 productos, campos id/name/description/price/deluxePrice/image/fechas | T-07, T-08 | E-HTTP búsqueda; E-CODE `server.ts:641`, `routes/search.ts:21` |
| REC-04 | Identidad actual | GET `/rest/user/whoami` | No enviada | Sin parámetros en esta prueba | 200 JSON, clave `user`, 11 bytes; no demuestra sesión autenticada | T-01 | E-HTTP whoami; E-CODE `server.ts:639` |
| REC-05 | Idiomas | GET `/rest/languages` | No enviada | Sin parámetros | 200, arreglo JSON de 4349 bytes | T-03 (disponibilidad) | E-HTTP idiomas; E-CODE `server.ts:661` |
| REC-06 | CAPTCHA de formulario | GET `/rest/captcha` | No enviada | Sin parámetros | 200, claves captchaId/captcha/answer; no se resolvió ni envió el formulario | T-03, T-02 | E-HTTP captcha; E-CODE `server.ts:654` |
| REC-07 | Metadatos de versión | GET `/rest/admin/application-version` | No enviada | Sin parámetros | 200, clave version; el nombre admin no demuestra control de rol ni vulnerabilidad | T-11 (validar alcance) | E-HTTP versión; E-CODE `server.ts:645` |

El GET de CAPTCHA genera datos efímeros normales del formulario. Su estructura es una observación, no un bypass confirmado. El acceso a una ruta llamada `admin` no prueba que deba estar restringida; determinar requisitos antes de clasificar un hallazgo.

## Superficie identificada en código; ejecución pendiente

| ID | Funcionalidad / formulario | Método y ruta identificados | Entradas / datos | Sesión / estado | Amenaza / requisito | Fuente precisa |
|---|---|---|---|---|---|---|
| REC-08 | Login | POST `/rest/user/login` | email/password; respuesta authentication con token, bid, umail | Sin envío; controles por comprobar | T-05 / RS-01; T-01 / RS-11 | E-CODE `server.ts:635`, `routes/login.ts:26,34` |
| REC-09 | Registro | POST `/api/Users` | Campos exactos de formulario pendientes en DevTools | No ejecutado | T-11 / RS-09 | E-CODE `server.ts:440,452`; ruta Angular register `app.routing.ts:175` |
| REC-10 | Carrito | GET `/rest/basket/:id` | id de cesta; productos/cantidades | Middleware de autorización en código; ejecución pendiente | T-06, T-10 / RS-02 | E-CODE `server.ts:388,642`, `basket.service.ts:45` |
| REC-11 | Añadir/editar cesta | POST `/api/BasketItems`, PUT `/api/BasketItems/:id` | ProductId, BasketId, quantity; id | Código usa sesión; no se cambió recurso | T-02, T-06 / RS-02, RS-07 | E-CODE `server.ts:458–459`, `basket.service.ts:196` |
| REC-12 | Checkout simulado | POST `/rest/basket/:id/checkout` | id, couponData, orderDetails | No ejecutado; confirmar campos reales | T-09, T-13 / RS-07, RS-06 | E-CODE `server.ts:643`, `basket.service.ts:65` |
| REC-13 | Cupón | PUT `/rest/basket/:id/coupon/:coupon` | id/coupon en ruta | No ejecutado | T-02 / RS-07 | E-CODE `server.ts:644`, `basket.service.ts:69` |
| REC-14 | Historial/seguimiento | GET `/rest/order-history`, GET `/rest/track-order/:id` | id de pedido; detalle exacto pendiente | No ejecutado; autorización por revisar | T-10, T-16 / RS-02, RS-13 | E-CODE `server.ts:656,663` |
| REC-15 | Feedback/contacto | POST `/api/Feedbacks` | Campos exactos pendientes; código verifica CAPTCHA | No enviado | T-08 / RS-04 | E-CODE `server.ts:434–438`; Angular contact `app.routing.ts:135` |

Las rutas Angular `search`, `login`, `register`, `basket`, `contact`, `order-history`, `order-summary` y `order-completion/:id` están en `frontend/src/app/app.routing.ts`. No se afirma que sus páginas hayan sido recorridas visualmente. Un HTTP 200 al documento SPA no confirma todas las rutas del frontend ni la existencia de un endpoint API arbitrario.

La emisión de JWT de 6 h se observa en `lib/insecurity.ts:54`. Almacenamiento de sesión, logout, cookie flags y revocación quedan pendientes de DevTools y análisis posterior. No se copiaron claves privadas ni bases de datos a evidencias.

## Completar con Chrome DevTools

1. Confirmar contenedores y abrir **8081**. F12 → Network → Fetch/XHR; recargar.
2. Recorrer catálogo y búsqueda con texto ordinario. Identificar formularios visibles.
3. Usar una cuenta ficticia propia para registro/login, carrito e historial, sin manipular IDs ajenos ni introducir payloads. Guardar evidencia de solicitudes normales.
4. Registrar método, ruta, nombre/tipo/ubicación de parámetros, necesidad de sesión, código y tipo de respuesta. Separar URL de SPA de endpoint HTTP.
5. Ocultar valores de passwords, Authorization, cookies, JWT y datos de cuenta. No versionar HAR crudo.
6. Contrastar con T-xx y RS-xx; compartir conclusiones con Sebas para revisión.

| Registro por completar | Acción normal | Método/ruta real | Parámetros (nombres/tipos/ubicación) | Sesión / código | Datos y límite | Fuente visual / fecha | Estado |
|---|---|---|---|---|---|---|---|
| UI-01 | Catálogo/búsqueda | Pendiente | Pendiente | Pendiente | LC-01/LC-02 | Pendiente | Pendiente |
| UI-02 | Registro/login | Pendiente | Sin valores secretos | Pendiente | LC-01/LC-02 | Pendiente | Pendiente |
| UI-03 | Carrito propio | Pendiente | ID propio y cantidades | Pendiente | LC-01/LC-02/LC-03 | Pendiente | Pendiente |
| UI-04 | Pedido simulado/historial | Pendiente | Pendiente | Pendiente | LC-01/LC-02/LC-03 | Pendiente | Pendiente |
| UI-05 | Feedback/contacto | Pendiente | Pendiente | Pendiente | LC-01/LC-02 | Pendiente | Pendiente |

**Balance:** 7 rutas observadas por HTTP; 8 entradas adicionales identificadas en código; 0 capturas de navegador; 0 explotaciones. No convertir hipótesis en hallazgos confirmados. Ver [criterios](04-Requisitos-y-casos-de-abuso.md) y [guía de evidencias](evidencias/README.md).
