# Evidencias académicas de H1

Destino autorizado: **http://127.0.0.1:8081/**. [Bitácora y reportes reales](VERIFICACION.md). Fecha local y UTC se distinguen en cada informe.

La [verificación de migración al fork](MIGRACION.md) registra la ejecución nueva.
Los informes anteriores se conservan como historial, incluidos sus fallos.
La ausencia de acceso al navegador que se menciona abajo corresponde a la
preparación anterior; esta migración no añade capturas ni prueba login/carrito.

## Capturas manuales pendientes

Los nombres siguientes son instrucciones de captura, no archivos ya creados. El navegador no estuvo accesible a la herramienta de automatización.

| Nombre sugerido | Qué mostrar | Responsable | Estado |
|---|---|---|---|
| `01-contenedores.png` | `docker compose ps`: dos healthy, solo WAF publicado en loopback 8081 | Blue | Pendiente |
| `02-entrada-waf.png` | Barra de dirección 127.0.0.1:8081 y catálogo de Juice Shop | Ambos | Pendiente |
| `03-network-publico.png` | DevTools, búsqueda normal y rutas/métodos/códigos visibles | Red | Pendiente |
| `04-network-login.png` | Login de cuenta ficticia con credenciales, JWT y cookies ocultos | Red | Pendiente |
| `05-carrito-pedido.png` | Operación ordinaria propia y Network, sin datos privados | Red | Pendiente |
| `06-waf-config.png` | DetectionOnly, BACKEND y publicación loopback de Compose | Blue | Pendiente |
| `07-waf-inspeccion.png` | Evento local con hora, productor CRS, regla 920350 y modo; sin payloads | Blue | Pendiente |
| `08-fork-publico.png` | Fork público que indique origen juice-shop/juice-shop y estado de workflows | Propietario | Pendiente |

El [DFD PNG](../DFD-referencia.png) sí existe: es un diagrama generado con Graphviz y revisado, no una captura de ejecución.

## Captura y sanitización

1. Confirmar destino/versión/contendedores. Abrir DevTools con F12, Network → Fetch/XHR y ejecutar una acción normal por captura.
2. Mostrar suficiente contexto para identificar método, ruta, resultado y URL local. Evitar pestañas personales y datos de otras aplicaciones.
3. Ocultar valores de Authorization, Cookie, Set-Cookie, contraseñas, JWT, correos reales y cualquier dato personal. Usar recorte/redacción opaca; no un desenfoque reversible. No reemplazar resultados reales.
4. No versionar HAR ni logs completos. Guardar originales sensibles, si son necesarios, en `privado/`, que está ignorado; revisar también el diff de archivos candidatos antes de publicar.
5. Añadir una fila al registro y someterla a revisión de Red/Blue. Una captura ausente permanece pendiente.

| ID | Archivo real | Fecha/hora y zona | Comando/acción | Resultado | Sanitización aplicada | Revisor |
|---|---|---|---|---|---|---|
| CAP-01 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |

## Recolectores disponibles

```powershell
python .\scripts\recopilar-evidencia-h1.py
python .\scripts\validar-h1.py
```

Ejecutar desde la raíz. El primero registra comandos y siete GET normales con metadatos, sin autenticación. Cada ejecución crea un JSON nuevo con hora UTC−06. El segundo revisa estructura, enlaces de archivos, requisitos, casos, referencias cruzadas, Compose y exclusiones Git; no demuestra que todos los controles de seguridad estén implementados.

Para citar resultados usar archivo y sección concretos, no afirmar que todo reporte fue exitoso: se conservan también intentos fallidos. Consultar [declaración de IA](../09-Fuentes-y-uso-IA.md) y adecuarla a la guía UVG antes de entregar.
