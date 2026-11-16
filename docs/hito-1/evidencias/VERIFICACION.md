# Bitácora técnica de H1

> **Registro histórico del proyecto anterior.** Las referencias a `main`,
> `fork=false` y migración pendiente describen aquel estado. Los JSON históricos
> se conservan sin reescribir sus resultados. Para el estado del fork y la nueva
> ejecución consultar [MIGRACION.md](MIGRACION.md).

Fechas en **America/Guatemala, UTC−06:00**; los eventos ModSecurity usan UTC. Trabajo local iniciado el 15 y revalidado el 16 de noviembre de 2026. No se hicieron commits, push ni pruebas ofensivas.

## Contexto inicial y procedencia

`git status` mostró árbol limpio y solo `README.md` versionado. Rama: `main`. `git remote -v` mostró `https://github.com/Gegdgt/Proyecto_Final_Desarrollo_Seguro` para fetch/push. La consulta de solo lectura a la API de GitHub confirmó `private=false`, `fork=false`: falta el fork oficial. El README básico y los 14 archivos del kit se conservaron; [manifiesto](../fuentes/MANIFIESTO.json).

Los informes JSON son extractos técnicos con argumentos de comandos, fecha, código de salida y resultado. Se omiten payloads/cabeceras sensibles; los fragmentos públicos de código tienen ruta y hash. No son capturas de navegador ni un informe de explotación.

## Resultados reproducibles

Desde la raíz del proyecto:

| Comando / método | Resultado observado |
|---|---|
| `docker compose -f .\entorno-blue-team\compose.yaml config` | Configuración válida, dos servicios, imágenes por digest, WAF DetectionOnly, red interna privada |
| `docker compose -f .\entorno-blue-team\compose.yaml up -d` | Arranque satisfactorio en 8081 tras corregir healthcheck y conflicto de puerto |
| `docker compose -f .\entorno-blue-team\compose.yaml ps` | Backend y WAF saludables en validación final; única publicación 127.0.0.1:8081 → 8080 |
| `docker inspect` de ambos contenedores | Backend sin PortBindings; WAF publica solo puerto 8080 interno en host 8081 |
| `docker network inspect juiceshop-h1_interna` | Internal=true y ambos servicios conectados |
| `docker compose ... exec -T waf httpd -t` | Código 0, Syntax OK |
| `docker compose ... exec -T waf httpd -M` | Módulos proxy y security2 cargados |
| `python scripts/recopilar-evidencia-h1.py` | Siete GET normales devuelven 200 y HTML raíz identifica Juice Shop |
| Auditoría seleccionada de `docker compose ... logs waf` | ModSecurity 2.9.15, CRS 4.30.0, `DETECTION_ONLY`, `proxy-server`, regla 920350 por Host numérico |
| Lectura de código mediante `/nodejs/bin/node` | Juice Shop 20.4.0-SNAPSHOT, Node v24.22.2; rutas, SQLite y MarsDB identificados |
| Graphviz `dot -Tsvg` / `dot -Tpng` | Diagramas regenerados; PNG revisado visualmente, sin recortes de texto |

No se envió tráfico directo a 3000: el criterio de no publicación se verifica mediante configuración y estado Docker. No se afirma bloqueo del WAF, integridad criptográfica de logs ni autorización funcional de todos los endpoints.

## Informes conservados

| Archivo | Contexto |
|---|---|
| [20261115-235121](verificacion-20261115-235121.json) | HTTP/WAF correctos; extracción de código falló por salto de línea en JavaScript. Se conserva el error, no se trata como ejecución completa |
| [20261115-235143](verificacion-20261115-235143.json) | Extractor corregido; dos nombres de archivos no existían, se identificaron después los reales. Literales de credenciales fixture retirados del extracto |
| [20261115-235210](verificacion-20261115-235210.json) | Referencia del inventario Red Team: siete GET, código real, auditoría |
| [20261116-072844](verificacion-20261116-072844.json) | Motor Docker detenido y conexiones HTTP rechazadas; intento fallido real, conservado |
| [20261116-072902](verificacion-20261116-072902.json) | Recuperación: motor iniciado, siete GET 200, código y WAF correctos; healthcheck del WAF aún iniciando en ese instante |

La verificación final de salud y el resultado de revisión documental se guardan en [VALIDACION-FINAL.json](VALIDACION-FINAL.json). El colector se ajustó para devolver salida distinta de cero si falla algún comando, HTTP o auditoría; informes anteriores deben interpretarse por su contenido, no solo por la salida del script.

## Incidentes y correcciones reales

1. **Motor ausente (15 y 16 de noviembre):** error `open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified`. Iniciar Docker Desktop con contenedores Linux restableció el motor. No se alteró la configuración de virtualización del sistema.
2. **Healthcheck:** `node` no existe en PATH de la imagen distroless; la aplicación usa `/nodejs/bin/node`. Se corrigió la ruta y el backend pasó a healthy.
3. **Conflicto 8080:** GET inicial devolvió HTML con referencia EnterpriseDB y “Server is up and running”, no Juice Shop. Docker informó `ports are not available ... bind ... forbidden by its access permissions`. No se estableció con certeza el proceso dueño del socket; se observaron procesos httpd, pero no se detuvieron. El propietario autorizó **8081** y se actualizó el alcance. No se volvió a explorar el servicio de 8080.
4. **Arranque inmediato del WAF:** primera solicitud respondió `Empty reply from server`; tras inicializar, devolvió 200. No se cambió el modo de seguridad para resolverlo.
5. **Dependencias externas:** backend advierte falta de Alchemy/LLM y claves; esos retos quedan fuera de H1. No se habilitó salida de backend ni se añadieron secretos.
6. **SSL de imagen WAF:** avisos de stapling por certificado propio de 8443, que no se publica. El recorrido probado es HTTP loopback, no TLS de producción.
7. **Diagramas:** Graphviz rechazó inicialmente BOM de PowerShell (`syntax error ... digraph`); se guardó DOT en UTF-8 sin BOM y se regeneraron PNG/SVG correctamente.
8. **Terminal Windows:** validación de enlaces mostró error de codificación al imprimir flechas con cp1252; scripts ahora emiten UTF-8. Se volvió a ejecutar la validación.
9. **Capturas:** herramienta de navegador informó `browser access host is unavailable` y canal nativo no disponible. Las capturas visuales quedan pendientes, sin reemplazarlas por imágenes generadas.

## Límites de las conclusiones

El DFD es un modelo sustentado por Compose/código y evidencia HTTP, no una captura de todos los flujos. La respuesta de búsqueda y los IDs justifican hipótesis; no demuestran IDOR, SQLi, XSS ni bypass de CAPTCHA. No se ejercitaron login, carrito, pedidos ni administración. La alerta CRS por IP numérica demuestra inspección de tráfico normal.

La configuración AHZ reduce el contenido de auditoría, pero mensajes de reglas/error/acceso aún pueden contener entradas sensibles. Solo se publican metadatos seleccionados. Retención, redacción completa y correlación de negocio están pendientes para H2/H3.
