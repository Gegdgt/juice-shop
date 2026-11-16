# PASTA IV — Análisis de amenazas con STRIDE

Son **hipótesis de diseño**, no vulnerabilidades explotadas. La lectura de código y las respuestas normales aportan superficie y plausibilidad; no sustituyen PoC ni revisión de controles. Se conservan T-01 a T-13 del kit y se añaden amenazas de despliegue y almacén documental.

STRIDE: **S** suplantación, **T** manipulación, **R** repudio, **I** divulgación, **D** denegación de servicio, **E** elevación de privilegios.

Revisión de migración: los componentes y flujos permanecen iguales en el fork.
T-15 también exige revisar los workflows heredados antes de publicar: el cambio
de repositorio no implementa los controles propuestos. Véanse el
[procedimiento de Actions](08-Migracion-fork.md) y los [resultados](evidencias/MIGRACION.md).

| ID | Componente / flujo | STRIDE | Amenaza | Activo | Impacto | Mitigación propuesta | Requisito | Caso |
|---|---|---|---|---|---|---|---|---|
| T-01 | A1 / sesión, F01 | S | Reutilizar una sesión robada | Cuenta/JWT | Alto: acciones como otro usuario | Caducidad, revocación y protección de tokens | RS-10, RS-11 | CA-09 |
| T-02 | A1 → P2, F01/F02 | T | Alterar parámetros o montos desde el cliente | Pedido/precio | Alto: integridad comercial | Validar esquema y recalcular en servidor | RS-07 | CA-06 |
| T-03 | P1/P2, F01/F02 | D | Agotar recursos mediante ráfagas | Disponibilidad | Medio: interrupción del laboratorio | Límites de tasa y observación de latencia | RS-05 | CA-05 |
| T-04 | P1/D3, F07 | R | Perder o no registrar eventos de seguridad | Auditoría | Alto: no reconstruir hechos | Metadatos correlacionables y revisión de retención | RS-06 | CA-07 |
| T-05 | P2 / autenticación | S | Adivinar credenciales mediante intentos repetidos | Credenciales/cuenta | Alto: suplantación | Límite de intentos y errores genéricos | RS-01 | CA-01 |
| T-06 | P2 / cesta/pedido | E | Acceder a recursos ajenos cambiando un ID | Carritos/pedidos | Alto: acceso horizontal indebido | Comprobar identidad y propietario en cada operación | RS-02 | CA-02 |
| T-07 | P2 → D1, F03 | T | Modificar la consulta mediante entrada de búsqueda | Base de datos | Alto: lectura o alteración | Consultas parametrizadas y validación de entradas | RS-03 | CA-03 |
| T-08 | P2 → A1, F05/F06 | T | Ejecutar contenido activo presentado como texto | Navegador/sesión | Alto: XSS y acciones no deseadas | Codificación contextual y política CSP adecuada | RS-04 | CA-04 |
| T-09 | P2 / cálculo de pedido | T | Aceptar precios o totales aportados por cliente | Totales/catálogo | Alto: pedido inconsistente | Recalcular desde catálogo autorizado | RS-07 | CA-06 |
| T-10 | D1/D2 → P2, F04/F09 | I | Devolver registros sin verificar titularidad | Datos privados | Alto: divulgación entre usuarios | Filtros de propietario y mínima respuesta | RS-02 | CA-02 |
| T-11 | P2 / funciones administrativas | E | Invocar operación privilegiada como usuario normal | Roles/datos administrativos | Alto: control no autorizado | Autorización de rol en backend | RS-09 | CA-08 |
| T-12 | P1/P2/D3, F07/F12 | I | Conservar contraseñas, cookies o JWT en registros | Secretos/sesiones | Alto: fuga por evidencia/logs | Reducir datos y redactar antes de exportar | RS-06, RS-10 | CA-07 |
| T-13 | P2 / transacciones | R | No atribuir una modificación de pedido | Historial de acciones | Alto: pérdida de trazabilidad | Registrar sujeto pseudónimo, recurso, acción y resultado | RS-06 | CA-07 |
| T-14 | Red Docker / P2 | E | Evitar el WAF usando puerto backend publicado | Aislamiento del laboratorio | Alto: controles omitidos | Publicar solo proxy en loopback | RS-08 | CA-10 |
| T-15 | Configuración / imágenes | T | Cambiar silenciosamente imagen mutable o incluir secretos | Reproducibilidad/repositorio | Alto: entorno distinto o credenciales expuestas | Digests fijos, revisión de diff y exclusiones específicas | RS-10, RS-12 | CA-11 |
| T-16 | P2 → D2, F08 | T | Alterar criterios/objetos de consulta documental | Reseñas/pedidos | Alto: datos o selección manipulados | Esquemas y operadores permitidos en servidor | RS-13 | CA-12 |

## Priorización y fundamento

PASTA IV relaciona actor, entrada, activo e impacto. A1 controla sus entradas y puede tener una cuenta ficticia; el actor abusivo hipotético intenta apropiarse de otra cuenta, modificar datos o degradar el servicio. A2 es operador privilegiado y un error suyo puede exponer el backend o publicar secretos.

Prioridad alta: T-06/T-10 por datos privados (ON-02/ON-03), T-07/T-16 por consultas (ON-01/ON-03), T-08 por navegador y sesión (ON-02), T-04/T-12/T-13 por trazabilidad (ON-05), T-14/T-15 por exposición/reproducibilidad del laboratorio. T-03 tiene prioridad media para disponibilidad (ON-04). Son valoraciones cualitativas, sin CVSS ni probabilidades inventadas.

El código empaquetado muestra consultas construidas con entradas en `routes/search.ts` y `routes/login.ts`; es un indicio estático que justifica T-07, no una prueba de explotación. La autorización y los IDs observados en `server.ts` justifican investigar T-06/T-11. La alerta CRS 920350 corresponde al Host numérico del acceso local normal y no demuestra SQLi, XSS ni ataque real.

## Cobertura por componente

| Componente | Amenazas aplicables |
|---|---|
| Navegador/Angular | T-01, T-02, T-08 |
| WAF | T-03, T-04, T-12 |
| API autenticación | T-01, T-05 |
| API de negocio | T-02, T-06, T-07, T-09, T-11, T-13, T-16 |
| SQLite/MarsDB | T-07, T-10, T-16 |
| Logs/operador | T-04, T-12, T-13 |
| Docker/configuración | T-14, T-15 |

Las seis categorías están cubiertas; no se fuerza una amenaza de cada categoría sobre cada componente. [Requisitos/casos](04-Requisitos-y-casos-de-abuso.md) y [reconocimiento con fuentes](05-RedTeam-reconocimiento.md) completan la trazabilidad.
