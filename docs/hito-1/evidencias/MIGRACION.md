# Verificación de la migración al fork

Fecha: **16 de noviembre de 2026**, America/Guatemala (UTC−06:00).
Destino: `Gegdgt/juice-shop`, rama local `hito-1-integracion`.
Sin commit, push ni cambios de ajustes remotos. El proyecto anterior se conserva.

## Evidencia de esta ejecución

- [Reporte HTTP, código, Docker y WAF](verificacion-20261116-075021.json).
- [Verificación de integridad, GitHub, enlaces y exclusiones](MIGRACION-VALIDACION.json).
- [Manifiesto de archivos del origen](../fuentes/MANIFIESTO-MIGRACION.json).
- [Bitácora anterior](VERIFICACION.md), conservada como historial.

Los informes históricos no se presentan como resultados de esta migración.
El recolector nuevo emitió código de salida 0 desde `juice-shop-proyecto`.

## Resultados comprobados

| Verificación | Resultado |
|---|---|
| Git inicial en ambos proyectos | Árboles limpios; origen `main`, destino `hito-1-integracion` |
| GitHub | Fork público `Gegdgt/juice-shop`, padre `juice-shop/juice-shop`, rama principal `master` |
| Rama de integración | Ya existente, en el mismo commit que `master` y `origin/master`: `266448aba68cd8ba5915f526a128da4fa7bc3f9f` |
| Compose | Configuración válida; copia idéntica al origen; hashes de servicios iguales a los contenedores existentes |
| Arranque desde destino | `up -d --no-recreate --wait --wait-timeout 60`, salida 0; contenedores conservados |
| Salud | `juice-shop` y `waf`: `running`, `healthy` |
| Publicación | Solo WAF: `127.0.0.1:8081` → `8080`; backend sin `PortBindings` |
| Aislamiento | Backend solo en `interna`, `internal=true`; WAF también en `entrada` |
| Apache | `httpd -t` correcto; módulos `security2` y proxy cargados |
| HTTP | Siete GET normales, todos 200; raíz contiene Juice Shop y responde a través de Apache |
| WAF | Siete eventos seleccionados: `proxy-server`, `DETECTION_ONLY`, regla CRS 920350 por Host numérico |
| Código e imagen | Nueve archivos del inventario coinciden por SHA-256 con blobs Git del commit base; revisión declarada de imagen `266448a` |
| PASTA/STRIDE | 16 amenazas, seis categorías, 13 requisitos, 12 casos; referencias cruzadas verificadas por script |
| DFD | DOT/SVG/PNG idénticos al origen; PNG revisado visualmente; arquitectura sin cambios |
| Fuentes oficiales | Sin modificaciones al código, dependencias, `scripts/package.mjs` ni los 16 workflows |
| README y exclusiones | Contenido oficial conservado; solo se añaden sección académica y reglas del laboratorio |
| Secretos y temporales | Revisión de candidatos, JSON y contenido del ZIP; no se detectaron secretos con los patrones usados; no se copian logs crudos, sesiones ni `.git` |

El control de secretos busca claves privadas, tokens GitHub, JWT, credenciales
en URL y asignaciones literales de contraseñas/tokens. Es una revisión acotada,
no una certificación de ausencia de cualquier secreto. Los fragmentos de código
son públicos y las evidencias HTTP no guardan cookies, Authorization ni cuerpos
de sesión. El código oficial contiene vulnerabilidades y fixtures deliberados;
no se han alterado ni clasificado como secretos introducidos por la migración.

## Correcciones de migración

1. El script anterior exigía que `package-lock.json` fuera versionable. Se
   ajustó a la exclusión oficial, sin sobrescribir `.gitignore`.
2. Se adaptaron enlaces al trasladar la guía académica desde la raíz a
   `docs/hito-1/GUIA-PROYECTO.md`. El validador comprueba archivos/directorios
   y anclas de los enlaces Markdown locales del README raíz y documentos H1.
   No verifica disponibilidad de todos los enlaces externos ni enlaces dentro
   del ZIP de procedencia o el README histórico en TXT.
3. Se corrigieron afirmaciones vigentes de «no es fork», código ausente y
   migración pendiente; los reportes históricos conservan su contexto original.
4. El recolector ahora exige que ambos servicios estén saludables, que la
   respuesta raíz identifique Juice Shop y que se observe DetectionOnly/CRS.
5. Se mantuvieron contenedores y hashes de configuración: sus etiquetas de
   creación aún mencionan la carpeta anterior. No hay montajes desde ella.

## Límites y requisitos pendientes

- `npm run lint`: salida 1 porque `eslint` no está instalado localmente.
- `npm test`: salida 1 al iniciar frontend porque `ng` no está instalado.
  No hay `node_modules` en raíz/frontend; no se atribuyen estos errores a las
  fuentes de Juice Shop. Instalar dependencias y repetir antes de commit.
- RSN no ejecutado: no se tocaron snippets, codefixes ni código de retos.
- Actions permite ejecución (`enabled=true`); la API enumera cero workflows
  y cero ejecuciones. Deshabilitación manual pendiente, sin afirmar que ya esté
  aplicada. [Inventario y procedimiento](../08-Migracion-fork.md).
- Faltan capturas reales, navegación autenticada ordinaria/DevTools y revisión
  conjunta Red/Blue. No se realizaron login, compras ni explotación en esta migración.
- Confirmar los cuatro integrantes, rúbrica original, aceptación académica de
  la excepción 8081 y declaración de IA según guía UVG. La alternativa de puerto
  está autorizada por el propietario; no se presume aprobación del docente.
- Publicación de la rama y revisión de PR hacia `master` del fork, solo tras
  autorización. H2–H4 permanecen sin iniciar.

El WAF inspecciona en DetectionOnly; no se certifica bloqueo. No hay SIEM,
persistencia de datos garantizada ni pruebas de remediación. La correspondencia
de nueve archivos no prueba que todas las dependencias/binarios de la imagen
sean reproducibles desde el fork. Los futuros cambios de código requieren
construir/alinear una nueva imagen; Compose no monta las fuentes del repositorio.
