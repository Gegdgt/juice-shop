# Requisitos de seguridad y casos de abuso

Requisitos de diseño con criterios de aceptación. La aplicación permanece intencionalmente vulnerable: **definir un requisito no implica implementarlo**. Los umbrales son decisiones propuestas del laboratorio, pendientes de revisión Red/Blue; no se atribuyen a OWASP ni a la configuración vigente.

## Requisitos verificables

| ID | Requisito | Criterio de aceptación | Estado / fase |
|---|---|---|---|
| RS-01 | Limitar autenticación fallida por cuenta e IP | Tras 5 fallos en 15 min, el sexto recibe 429 y Retry-After; mensaje no revela existencia de cuenta. Umbral propuesto para el laboratorio | H2/H3 · propuesto |
| RS-02 | Autorizar cada lectura/escritura por propietario | Con cuentas A/B, acceso de A a recurso B devuelve 403/404, sin datos de B ni cambio de estado | H2 · propuesto |
| RS-03 | Parametrizar consultas SQL | Revisión confirma parámetros separados de SQL y prueba local controlada no altera selección ni devuelve error SQL crudo | H2 · propuesto |
| RS-04 | Codificar contenido por contexto y restringir scripts | Texto de prueba se muestra inerte; ningún manejador/script aportado se ejecuta; revisar CSP sin usarla como sustituto del escape | H2 · propuesto |
| RS-05 | Limitar abuso de solicitudes | Umbral de diseño: 60 solicitudes/minuto/IP por ruta; exceso 429. En prueba aprobada posterior, cliente ordinario conserva HTTP 200 y p95 menor a 2 s en equipo documentado | H2/H3 · propuesto, sin prueba de carga H1 |
| RS-06 | Registrar seguridad y acciones sin secretos | Evento tiene hora UTC, ID correlacionable, ruta, acción/resultado y sujeto pseudónimo cuando aplique; muestra exportada sin contraseñas/JWT/cookies. Verificar WAF y negocio por separado | H1 parcial: metadatos WAF observados; auditoría de negocio/redacción completa pendiente |
| RS-07 | Calcular totales en servidor | Montos alterados por cliente no cambian precio autorizado; total igual a catálogo × cantidad válida más reglas aprobadas | H2 · propuesto |
| RS-08 | Restringir publicación al WAF local | Docker inspect: única publicación 127.0.0.1:8081 → waf:8080; backend PortBindings vacío; red interna internal=true | H1 verificado |
| RS-09 | Autorizar administración en backend | Cuenta normal obtiene 403/404 para operación administrativa real; estado permanece igual | H2 · propuesto |
| RS-10 | Evitar secretos en repositorio/evidencia y proteger transporte | Revisión de archivos candidatos sin credenciales reales, sesiones ni HAR; .env ignorado y ejemplos permitidos. HTTP solo loopback; cualquier despliegue no local requiere HTTPS y nueva autorización | H1 parcial; excepción HTTP local documentada |
| RS-11 | Controlar expiración y revocación de sesiones | Token expirado o invalidado por cierre de sesión recibe 401; sesión activa legítima funciona. Propuesta: inactividad 30 min y máximo 2 h | H2 · propuesto; código observado emite JWT de 6 h, sin ensayo de revocación |
| RS-12 | Fijar imágenes reproducibles | Ambas referencias incluyen @sha256 de 64 dígitos y coinciden con las imágenes desplegadas; repetir evaluación al cambiarlas | H1 verificado |
| RS-13 | Validar entradas de consultas documentales | Esquema permite solo campos/tipos previstos; operadores inesperados se rechazan con 400 sin modificar documentos ajenos | H2 · propuesto |

## Casos de abuso

Todos se diseñan en H1. Los ensayos ofensivos requieren alcance y autorización del hito posterior.

### CA-01 — Abuso del inicio de sesión

**Amenazas:** T-05. **Requisitos:** RS-01.

**Precondiciones:** Cuenta sintética y ventana de mantenimiento aprobada; sin cuentas reales.

**Dado** un cliente sin sesión, **Cuando** supera cinco intentos fallidos en 15 minutos, **Entonces** el sexto intento se limita sin revelar la cuenta.

**Resultado de seguridad esperado:** 429 y registro sin contraseña.

**Verificación posterior:** H2: prueba secuencial acotada y revisión de contador/log; no ejecutada en H1.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-02 — Acceso al carrito/pedido de otra cuenta

**Amenazas:** T-06, T-10. **Requisitos:** RS-02.

**Precondiciones:** Dos cuentas ficticias y recursos propios conocidos.

**Dado** la cuenta A autenticada, **Cuando** solicita o modifica un recurso de B, **Entonces** el servidor deniega y conserva datos/estado de B.

**Resultado de seguridad esperado:** 403/404 sin contenido privado.

**Verificación posterior:** H2: comparar respuesta y estado anterior/posterior con las dos cuentas.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-03 — Inyección SQL en búsqueda

**Amenazas:** T-07. **Requisitos:** RS-03.

**Precondiciones:** Ruta identificada, conjunto de prueba y respaldo de laboratorio.

**Dado** un campo de búsqueda controlado por cliente, **Cuando** recibe una entrada de prueba que intenta cambiar la consulta, **Entonces** el backend la trata como dato.

**Resultado de seguridad esperado:** Sin modificación de selección ni error SQL crudo.

**Verificación posterior:** H2: revisión de parametrización y PoC acotada; comparar resultados con consulta de control.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-04 — XSS en texto mostrado

**Amenazas:** T-08. **Requisitos:** RS-04.

**Precondiciones:** Campo visible identificado y perfiles de navegador de prueba.

**Dado** un contenido aportado por usuario, **Cuando** se representa en un contexto HTML o atributo, **Entonces** se codifica y permanece inerte.

**Resultado de seguridad esperado:** No se ejecuta código ni se accede a sesiones.

**Verificación posterior:** H2: observar DOM/console con marcador controlado y revisar codificación contextual.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-05 — Abuso por ráfagas

**Amenazas:** T-03. **Requisitos:** RS-05.

**Precondiciones:** Umbral 60/min propuesto, límites de recursos y criterio de parada aprobados.

**Dado** un cliente que repite una ruta, **Cuando** excede el umbral, **Entonces** se limita y se conserva servicio ordinario.

**Resultado de seguridad esperado:** 429 para exceso y cliente ordinario disponible.

**Verificación posterior:** H2/H3: ensayo acotado con métricas p95/errores; no carga ni DoS en H1.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-06 — Manipulación del precio o total

**Amenazas:** T-02, T-09. **Requisitos:** RS-07.

**Precondiciones:** Carrito sintético y precios de referencia guardados.

**Dado** un pedido ficticio, **Cuando** el cliente altera montos/cantidades enviados, **Entonces** el servidor valida cantidades y recalcula.

**Resultado de seguridad esperado:** Total conforme a catálogo y reglas, sin aceptar monto arbitrario.

**Verificación posterior:** H2: comparar total esperado y persistido; nunca una compra real.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-07 — Pérdida de trazabilidad o secretos en logs

**Amenazas:** T-04, T-12, T-13. **Requisitos:** RS-06, RS-10.

**Precondiciones:** Acceso local a registros y marcadores sintéticos.

**Dado** una acción de prueba, **Cuando** se procesa y consulta su registro, **Entonces** hay evento correlacionable sin secretos completos.

**Resultado de seguridad esperado:** Fecha, ruta, resultado, ID y sujeto cuando aplique; sin credenciales.

**Verificación posterior:** H1: metadatos de GET normal verificados. H2/H3: revisar transacciones, redacción, retención e integridad con canarios ficticios.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-08 — Uso de funciones administrativas

**Amenazas:** T-11. **Requisitos:** RS-09.

**Precondiciones:** Ruta administrativa identificada y cuenta normal ficticia.

**Dado** un usuario sin rol de administración, **Cuando** invoca una operación privilegiada, **Entonces** el backend deniega la operación.

**Resultado de seguridad esperado:** 403/404 y estado intacto.

**Verificación posterior:** H2: probar acción real y revisar rol en servidor; ocultar menú no es suficiente.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-09 — Reutilización indebida de sesión

**Amenazas:** T-01. **Requisitos:** RS-10, RS-11.

**Precondiciones:** Sesión propia ficticia y política temporal de diseño.

**Dado** un token expirado o invalidado al salir, **Cuando** se intenta reutilizar en un recurso privado, **Entonces** la API lo rechaza.

**Resultado de seguridad esperado:** 401 sin datos privados; sesión legítima sigue operativa.

**Verificación posterior:** H2: caducidad/cierre de sesión con token propio, sin publicar su valor.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-10 — Acceso directo al backend

**Amenazas:** T-14. **Requisitos:** RS-08.

**Precondiciones:** Compose y contenedores locales disponibles.

**Dado** una configuración de laboratorio, **Cuando** se inspeccionan puertos y redes, **Entonces** solo el WAF tiene publicación loopback.

**Resultado de seguridad esperado:** PortBindings de backend vacío y red interna privada.

**Verificación posterior:** H1: docker inspect y Compose; no es necesario enviar tráfico directo al puerto 3000.

**Estado:** Comprobación de infraestructura realizada; véase evidencia H1.

### CA-11 — Deriva de imagen o secreto versionado

**Amenazas:** T-15. **Requisitos:** RS-10, RS-12.

**Precondiciones:** Diff de entrega y referencias de imágenes conocidas.

**Dado** una modificación del entorno, **Cuando** se revisan imágenes y archivos candidatos, **Entonces** no se aceptan etiquetas flotantes ni secretos reales.

**Resultado de seguridad esperado:** Digests coincidentes y entrega sanitizada.

**Verificación posterior:** H1: Compose/inspect, git diff y check-ignore; sin afirmar que .gitignore detecta todo secreto.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

### CA-12 — Manipulación de consulta documental

**Amenazas:** T-16. **Requisitos:** RS-13.

**Precondiciones:** Entrada de reseñas/pedidos identificada y datos sintéticos.

**Dado** un objeto controlado por cliente, **Cuando** incluye campos u operadores no admitidos, **Entonces** la API valida esquema y deniega entradas inválidas.

**Resultado de seguridad esperado:** 400 sin lectura ni cambio de documentos ajenos.

**Verificación posterior:** H2: revisión de construcción de consultas MarsDB y casos negativos controlados.

**Estado:** Diseñado; sin ejecución ofensiva. Las observaciones parciales no acreditan el caso completo.

La matriz [STRIDE](03-PASTA-4-STRIDE.md) permite recorrer amenaza → requisito → caso. [Checklist](07-CHECKLIST.md) distingue diseño completado de control validado.
