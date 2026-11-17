# Hito 2 — Paquete completo de evidencias Red Team (OWASP Juice Shop)

**Fecha:** 17 de noviembre de 2026.  
**Alcance autorizado:** únicamente `http://127.0.0.1:8081/`, instancia local de OWASP Juice Shop tras el WAF.  
**Herramientas:** OWASP ZAP, Burp Suite Community (Proxy + Repeater), PowerShell/curl.  
**Nota:** este es un paquete local para revisión; **no se modificó el fork GitHub**.

## Contenido y explicación de cada captura

| Carpeta | Archivo | Explicación concreta |
|---|---|---|
| 00_Configuracion | `01_ZAP_Proxy_Local_127_0_0_1_Puerto_8090.png` | ZAP escuchando en loopback por el puerto 8090, evitando conflicto con el laboratorio. |
| 00_Configuracion | `02_Burp_Proxy_8091_Activo_8080_Inactivo.png` | Listener activo de Burp en 8091; el de 8080 no se utiliza. |
| 00_Configuracion | `03_Burp_HTTP_History_Solicitudes_Localhost_8081.png` | Burp captura solicitudes reales de Juice Shop. |
| 01_Reporte_ZAP | `Reporte_Original_ZAP_by_Checkmarx_Scanning_Report.html` | Reporte HTML original de ZAP sin modificaciones. Las alertas son resultados automáticos, no vulnerabilidades confirmadas por sí solas. |
| 02_PoC_01_SQLi_Busqueda | `01_Control_Sin_Filtro_HTTP_200_Listado_General.png` | Consulta GET sin término de búsqueda; establece un punto de comparación. |
| 02_PoC_01_SQLi_Busqueda | `02_Control_Consulta_Apple_HTTP_200_Resultados_Filtrados.png` | Consulta normal con `q=apple`, HTTP 200, `Content-Length: 1617`. |
| 02_PoC_01_SQLi_Busqueda | `03_Inyeccion_SQL_OR_1_igual_1_HTTP_200_Mas_Productos.png` | Entrada de inyección en `q`, HTTP 200, `Content-Length: 34158` y datos adicionales: evidencia de SQLi. |
| 03_PoC_02_SQLi_Login | `01_Control_Login_Clave_Incorrecta_HTTP_401_Rechazado.png` | Login con contraseña incorrecta, acceso rechazado. Clave ocultada. |
| 03_PoC_02_SQLi_Login | `02_SQLi_Login_Comentario_SQL_HTTP_200_Autenticacion_JWT_Oculto.png` | El correo con comentario SQL y contraseña incorrecta obtiene HTTP 200 y objeto de autenticación. JWT oculto. |
| 03_PoC_02_SQLi_Login | `03_Control_Login_Correcto_HTTP_200_JWT_Oculto.png` | Login legítimo HTTP 200 para comparar; credenciales y JWT ocultos. |
| 04_PoC_03_IDOR_Carrito | `01_Cuenta_B_Historial_Carrito_7_HTTP_200.png` | Historial HTTP del carrito 7 de la cuenta de prueba B. |
| 04_PoC_03_IDOR_Carrito | `02_Cuenta_A_Historial_Carrito_6.png` | Historial HTTP del carrito 6 de la cuenta de prueba A. |
| 04_PoC_03_IDOR_Carrito | `03_Cuenta_A_Consulta_Carrito_6_HTTP_304_Cache_Token_Oculto.png` | Respuesta 304 por caché al consultar el carrito 6; NO equivale a autorización denegada. |
| 04_PoC_03_IDOR_Carrito | `04_Consulta_Carrito_7_HTTP_200_Banana_Juice_Pendiente_Validar_Token_A.png` | Respuesta HTTP 200 con Banana Juice del carrito 7. **Falta comprobar inequívocamente que la credencial usada pertenece a A**, no a B. |
| 05_PoC_04_Exposicion_Directorio_FTP | `01_Burp_Con_Sesion_Listado_FTP_HTTP_200_Credenciales_Ocultas.png` | Burp Repeater devuelve lista de archivos de `/ftp/` con sesión; tokens ocultos. |
| 05_PoC_04_Exposicion_Directorio_FTP | `02_PowerShell_SIN_Autenticacion_FTP_HTTP_200_Listado_JSON.png` | **Evidencia principal**: `curl` sin cookies ni Authorization obtiene HTTP 200 y nombres de archivos de `/ftp/`. |
| 05_PoC_04_Exposicion_Directorio_FTP | `03_Transcripcion_Sanitizada_Curl_Anonimo_HTTP_200.txt` | Transcripción compacta del comando y salida de la evidencia principal (no nueva ejecución). |
| 99_Diagnostico_Entorno | `01_Intermitencia_WAF_502_Bad_Gateway_NO_Es_Evidencia_De_Exposicion.png` | Navegador incógnito muestra error 502 ocasional. **Esto es un diagnóstico del proxy, NO prueba de exposición ni bloqueo del WAF**. Favoritos ocultados por privacidad. |

## Hallazgos y estado de validación

### PoC-01 — SQL Injection en búsqueda

- **Endpoint:** `GET /rest/products/search?q=...`.
- **Observado:** la consulta normal `apple` entrega resultados filtrados; la entrada SQLi hace que se devuelvan datos adicionales que no corresponden al filtro.
- **Estado:** confirmada en el laboratorio (evidencia funcional, no solo tamaño de respuesta).
- **Clasificación propuesta:** OWASP Top 10:2025 A05 Injection; CWE-89.

### PoC-02 — SQL Injection en login

- **Endpoint:** `POST /rest/user/login`.
- **Observado:** credenciales incorrectas normalmente producen HTTP 401; modificando el correo con comentario SQL, las mismas credenciales incorrectas obtienen HTTP 200 y objeto `authentication`.
- **Estado:** confirmada en cuenta de prueba local.
- **Clasificación propuesta:** OWASP Top 10:2025 A05 Injection; CWE-89.

### PoC-03 — Acceso a carrito ajeno (candidato IDOR)

- **Endpoint:** `GET /rest/basket/:id`.
- **Observado:** los carritos 6 (cuenta A) y 7 (cuenta B) existen; una solicitud de carrito 7 devuelve Banana Juice con HTTP 200.
- **Estado:** **pendiente de verificación de identidad del token del solicitante**; para afirmarlo como IDOR, la llamada al carrito 7 debe realizarse con autenticación de A, no con la de B. Los JWT quedaron cubiertos y eso impide demostrar la identidad comparando capturas por sí solas.
- **Clasificación candidata:** OWASP Top 10:2025 A01 Broken Access Control; CWE-639.

### PoC-04 — Listado del directorio FTP sin autenticación

- **Endpoint:** `GET /ftp/`.
- **Observado:** `curl -i --noproxy "*" -H "Accept: application/json"` sin credenciales devuelve HTTP 200 y listado JSON de 11 entradas, entre ellas `incident-support.kdbx`, `package.json.bak` y `suspicious_errors.yml`.
- **Estado:** confirmada la **enumeración anónima de nombres de archivos**. No se requiere ni se demuestra descarga de contenido sensible.
- **Clasificación propuesta:** OWASP Top 10:2025 A02 Security Misconfiguration; CWE-548.

## Nota de robustez y errores intermitentes

El WAF también devolvió respuestas `408 Request Timeout` y `502 Bad Gateway` en ensayos anteriores. La evidencia de PoC-04 se basa en la respuesta anónima posterior **HTTP 200 con listado JSON**, no en esos errores. El error 502 queda separado en la carpeta diagnóstica y no se presenta como hallazgo de seguridad.

## Qué falta antes de considerar cerrado el entregable académico

- Confirmar que el token de **cuenta A** se usó para solicitar el **carrito B**. Puede hacerse comparando el identificador de cuenta extraído localmente de ambas sesiones, sin publicar los JWT.
- Justificar el **vector completo y puntaje CVSS v3.1** de cada vulnerabilidad que se declare confirmada. No se asignan puntuaciones sin evaluar las métricas.
- Verificar la trazabilidad y el contenido final de los informes del Hito 2 según la rúbrica de la UVG.

## Privacidad y uso

Las imágenes históricas con cabeceras de autorización, cookies y contraseñas se tomaron de versiones sanitizadas con máscaras opacas. **No se incluyen aquí los originales con tokens o contraseñas visibles**. El reporte HTML ZAP se conserva íntegro y, en una comprobación textual, no contiene tokens `Bearer` ni JWT reconocibles; aun así, revisar su contenido antes de una publicación pública. Ninguna de estas capturas se creó mediante una nueva prueba: representan resultados enviados por el usuario.
