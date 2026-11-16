# PASTA I — Objetivos y PASTA II — Alcance técnico

> Caso de estudio: tienda electrónica **de demostración** OWASP Juice Shop. Los objetivos de negocio son supuestos del ejercicio, no afirmaciones sobre operaciones comerciales reales.

## Etapa I: definición de objetivos de negocio

**Propósito funcional:** permitir que una persona consulte un catálogo, use una cuenta, cree una cesta y complete flujos de compra simulada.

| ID | Objetivo de negocio | Activo principal | Impacto si falla | Objetivo de seguridad asociado |
|---|---|---|---|---|
| ON-01 | Permitir consultas confiables al catálogo | Productos/precios | Medio: información de productos manipulada | Integridad del catálogo y precios |
| ON-02 | Proteger cuentas de usuarios de prueba | Credenciales/sesiones | Alto: acceso a datos y acciones de otra cuenta | Autenticación, sesión segura, control de acceso |
| ON-03 | Mantener separados pedidos y carritos | Pedidos/detalles de carrito | Alto: lectura o modificación entre usuarios | Autorización por recurso |
| ON-04 | Mantener disponibilidad razonable | Aplicación y API | Medio/alto: servicios inutilizables | Control de tasa, monitoreo |
| ON-05 | Poder reconstruir eventos sospechosos | Logs de WAF y app | Alto: pérdida de trazabilidad | Registro, integridad y protección de logs |

**Datos y clasificación:** credenciales y tokens (secretos); datos de cuenta y pedidos (sensibles del laboratorio); catálogo (público); logs (internos, potencialmente sensibles). Usar únicamente cuentas ficticias y datos de prueba.

**Requisitos generales de seguridad:** mínimos privilegios, autorización de servidor, validación de entradas, trazabilidad, privacidad de tokens y resiliencia básica. Requisitos medibles en `04-Requisitos-y-casos-de-abuso.md`.

**Restricción del ejercicio:** solo despliegue y pruebas locales autorizadas; nunca el Juice Shop público ni terceros.

## Etapa II: alcance técnico

| Capa / componente | Tecnología / ubicación | ¿Incluido? | Notas |
|---|---|---|---|
| Navegador y frontend | Angular SPA, ejecutada en navegador | Sí | Cliente fuera del límite confiable del backend |
| Proxy/WAF | ModSecurity + OWASP CRS, contenedor local | Sí | Recibe solicitudes en `127.0.0.1:8081`; comienza en `DetectionOnly` |
| Backend | Node.js / Express / REST, contenedor Juice Shop | Sí | Servicio `juice-shop:3000` accesible desde la red Docker; no se publica directamente en el host |
| Datos internos | SQLite + colecciones MarsDB dentro de Juice Shop | Sí | `models/index.ts:42`: `data/juiceshop.sqlite`; `data/mongodb.ts:9–10`: reseñas y pedidos. Sin servicio DB separado ni persistencia garantizada |
| Control de versiones | Fork público `Gegdgt/juice-shop`, rama principal `master` | Sí | Código oficial en la raíz; H1 integrado localmente en `hito-1-integracion`, publicación pendiente |
| SIEM / Filebeat / Kibana | Fase H3 | Futuro | No aparece como componente operativo en el DFD H1 |
| SAST / SCA / DAST / SBOM | Fase H2 | Futuro | No confundir requisitos deseados con controles que ya funcionan |
| Servicio público y universidad | Infraestructura de terceros | **No** | Fuera de alcance y prohibido hacer pruebas |

**Entorno esperado:** Windows con Docker Desktop (WSL 2) y `docker compose`.

**Verificado:** imagen 20.4.0-SNAPSHOT, siete rutas GET y auditoría DetectionOnly. JWT se identifica por lectura de código; login interactivo, almacenamiento en navegador y autorizaciones quedan pendientes. Véase [reconocimiento](05-RedTeam-reconocimiento.md).

**Criterio de éxito del alcance:** navegador llega a la tienda **por el WAF** (`http://127.0.0.1:8081/`), sin puerto 3000 publicado por Docker; los contenedores aparecen activos en `docker compose ps`.

## Actores, prioridades y criterios de negocio

| Actor | Confianza / capacidad | Objetivo en H1 |
|---|---|---|
| A1 visitante / cliente ficticio | Entradas no confiables; anónimo o autenticado | Consultar catálogo y estudiar flujos |
| A2 operador Red/Blue | Acceso autorizado al host y Docker, privilegio alto | Desplegar, observar y revisar evidencias |
| Actor abusivo hipotético | Control de entradas del navegador y de su propia cuenta | Modelar abuso; no ejecutarlo en H1 |

| Prioridad | Propiedad | Objetivo verificable de diseño | Impacto |
|---|---|---|---|
| Alta | Confidencialidad | Ningún usuario accede a datos privados de otro; RS-02, RS-10, RS-11 | Exposición de cuentas, direcciones, pedidos o sesiones ficticias |
| Alta | Integridad | Consulta y monto final no dependen de entradas sin validar; RS-03, RS-04, RS-07 | Catálogo, pedidos o navegador manipulados |
| Media | Disponibilidad | Uso ordinario sigue respondiendo bajo límites definidos; RS-05 | Interrupción del laboratorio y pérdida de evidencia |
| Alta | Trazabilidad | Eventos recuperables con fecha, contexto y sin secretos; RS-06 | Imposibilidad de reconstruir acciones |
| Alta | Contención | Solo WAF publica en loopback; RS-08 | Exposición accidental de aplicación vulnerable |

No se asignan pérdidas monetarias ficticias: el impacto es académico y sobre datos sintéticos. El modelo de negocio es una tienda simulada, no una operación comercial. Catálogo/precios son públicos, credenciales/JWT son secretos, carritos/pedidos/direcciones son privados y los logs son internos.

Quedan fuera: pagos reales, OAuth externo, Alchemy, LLM externo, universidad, servicios públicos, SIEM, pruebas de explotación, SAST/SCA/DAST y remediación. La red interna impide depender de Internet desde el backend. La excepción 8081 fue autorizada por conflicto de 8080; cualquier cambio de destino requiere revisar el alcance.

Fuentes: [evidencia local](evidencias/VERIFICACION.md), [PASTA](https://versprite.com/cybersecurity-listings/devsecops/pasta-threat-modeling/) y [referencias](09-Fuentes-y-uso-IA.md).
