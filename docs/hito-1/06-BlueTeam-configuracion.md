# Blue Team — Configuración y controles

**Responsable:** Sebas Juárez. Arquitectura: navegador → **127.0.0.1:8081** → WAF:8080 → `interna` → Juice Shop:3000 → SQLite/MarsDB internos. La excepción de puerto fue autorizada por el propietario; 8080 del host pertenece a otro servicio. [Compose](../../entorno-blue-team/compose.yaml).

## Configuración de H1

| Ajuste | Propósito / resultado |
|---|---|
| Imágenes por digest | Congelar los artefactos verificados, incluida la variante Apache del WAF |
| `BACKEND=http://juice-shop:3000` | Resolución DNS de servicio y proxy inverso |
| `PORT=8080` / publicación 8081 | Puerto de escucha interno y único punto local autorizado |
| `MODSEC_RULE_ENGINE=DetectionOnly` | Evaluar reglas sin bloqueo de ModSecurity |
| `MODSEC_AUDIT_ENGINE=On` | Registrar auditoría aun para tráfico normal |
| `MODSEC_AUDIT_LOG=/dev/stdout`, JSON | Acceso mediante Docker logs y futura recolección SIEM |
| `MODSEC_AUDIT_LOG_PARTS=AHZ` | Reducir datos: metadatos y resumen; omite cuerpos y cabeceras completas, pero los mensajes pueden incluir fragmentos sensibles |
| `json-file`, 10m × 3 | Rotación local por contenedor; no es retención académica ni almacén inmutable |
| `interna: internal: true` | Backend sin salida ordinaria a redes externas y sin `ports` |
| `entrada` solo en WAF | Red bridge del punto de entrada; no convierte el WAF en proxy público |
| Healthcheck y depends_on | Esperar a Juice Shop saludable; usar `/nodejs/bin/node` real |

La imagen usa variables de Apache en directivas como `SecRuleEngine ${MODSEC_RULE_ENGINE}`: ver texto de configuración solamente no prueba resolución. El evento real incluye `engine_mode=DETECTION_ONLY` y productores ModSecurity/CRS, además de `handler=proxy-server`.

## Verificación desde la raíz

```powershell
docker compose -f .\entorno-blue-team\compose.yaml config
docker compose -f .\entorno-blue-team\compose.yaml up -d
docker compose -f .\entorno-blue-team\compose.yaml ps
docker compose -f .\entorno-blue-team\compose.yaml exec -T waf httpd -t
docker compose -f .\entorno-blue-team\compose.yaml exec -T waf httpd -M
docker inspect juiceshop-h1-juice-shop-1 --format '{{json .HostConfig.PortBindings}}'
docker inspect juiceshop-h1-waf-1 --format '{{json .NetworkSettings.Ports}}'
docker network inspect juiceshop-h1_interna --format '{{json .Internal}}'
curl.exe --noproxy '*' --max-time 15 -I http://127.0.0.1:8081/
python .\scripts\recopilar-evidencia-h1.py
```

Esperado: dos contenedores healthy, `Syntax OK`, módulo `security2_module`, WAF publicado solo en 127.0.0.1:8081, backend sin asignaciones de host y red interna `true`. `3000/tcp` sin flecha en `ps` solo indica puerto interno. No probar directamente 3000: la inspección de Docker comprueba la ausencia de publicación sin ampliar el alcance HTTP.

## Evidencia de inspección WAF

Consultar `docker compose -f .\entorno-blue-team\compose.yaml logs --tail=30 waf`. Un GET normal por IP numérica produjo la regla **920350**, mensaje *Host header is a numeric IP address*, CRS 4.30.0. La respuesta fue 200. Esto demuestra evaluación del CRS en el proxy; no es un ataque ni un ensayo de bloqueo. Conservar hora UTC, ID de transacción, productor, modo y resultado HTTP correlacionado por orden/tiempo. No afirmar correlación criptográfica entre HTTP y auditoría: el recolector no captura un ID de respuesta.

La parte AHZ no contiene por sí sola ruta/estado para toda transacción. La ruta puede aparecer en error/access logs, cuyos campos y privacidad deben ajustarse al integrar SIEM en H3. RS-06 es **parcial**: falta auditoría de acciones de negocio, redacción robusta, integridad y conservación. Revisar una muestra antes de exportarla; nunca subir logs crudos.

## Amenazas y límites

LC-01: entradas no confiables (T-01/T-02/T-08); LC-02: WAF no reemplaza permisos ni evita abuso por sí solo (T-03/T-06/T-11); LC-03: SQL y documentos requieren controles en aplicación (T-07/T-10/T-16); LC-04: secretos y pérdidas de logs (T-04/T-12/T-13). La publicación directa y deriva de imágenes son T-14/T-15. [Matriz](03-PASTA-4-STRIDE.md).

| Estado | Controles / requisitos |
|---|---|
| Operativo y observado | Loopback/red interna y backend sin publicación (RS-08), digests fijados (RS-12), inspección CRS y logs locales |
| Parcial | RS-06 metadatos; RS-10 exclusiones/revisión de evidencia y excepción HTTP local |
| Propuesto para H2 | RS-01/02/03/04/07/09/11/13: autenticación, autorización, consultas, XSS, precios y sesiones; no remediados en H1 |
| Propuesto para H2/H3 | RS-05 límites medidos y validación; bloqueo WAF solo después de ajustar falsos positivos |
| Futuro H3 | SIEM, ingesta, dashboards, alertas, retención e integridad; no desplegados |

## Pendientes de Sebas

Tomar capturas reales de `ps`, configuración y evento WAF; revisar DFD/STRIDE con Red Team; acordar umbrales; revisar logs por secretos; confirmar requisitos de rúbrica y preparar futura ingesta sin instalarla ahora. No marcar conformidad de controles de aplicación basándose solo en la presencia del WAF.

Para detener: `docker compose -f .\entorno-blue-team\compose.yaml stop`. Para retirar: `down`, conservando antes evidencia sanitizada. No existe garantía de persistencia del progreso: el arranque recrea tablas. Diagnósticos observados y soluciones están en la [guía del proyecto](GUIA-PROYECTO.md).

Tras la migración, gestionar `juiceshop-h1` únicamente desde `juice-shop-proyecto`.
Compose conserva nombre de proyecto, digests, redes y puertos. Los contenedores
existentes pueden conservar etiquetas con la ruta anterior: no significa que
se ejecute código desde esa carpeta, pues no hay bind mounts ni build local.
No ejecutar Compose simultáneamente desde ambas copias ni recrear contenedores
solo para cambiar etiquetas; se perderían datos efímeros y logs.
