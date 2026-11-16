# Migración al fork oficial y publicación pendiente

El 16 de noviembre de 2026 se verificó mediante Git y la API de GitHub:

| Dato | Resultado |
|---|---|
| Origen académico | `Gegdgt/Proyecto_Final_Desarrollo_Seguro`, rama `main` |
| Commit de origen | `fc44a997d1f6d55a1f11576cd93be5c691c29133` |
| Destino definitivo | [Gegdgt/juice-shop](https://github.com/Gegdgt/juice-shop), público, `fork=true` |
| Repositorio padre | `juice-shop/juice-shop` |
| Rama principal | `master`, confirmada también con `git ls-remote --symref origin HEAD` |
| Base de integración | `266448aba68cd8ba5915f526a128da4fa7bc3f9f` |
| Rama local | `hito-1-integracion`, ya existente y limpia al iniciar, basada en `origin/master` |
| Publicación | Pendiente; sin commit ni push durante la migración |

La base `master` se utiliza por la instrucción de integración en este fork.
No se está preparando una contribución al `develop` de OWASP ni un PR upstream.
El proyecto anterior permanece intacto, incluidos su `.git`, rama e historial.
Los [resultados](evidencias/MIGRACION.md) y el
[manifiesto de origen](fuentes/MANIFIESTO-MIGRACION.json) permiten revisar la copia.

## Integración realizada

- Se copiaron todos los archivos de `docs/hito-1/`, incluidos diagramas,
  evidencias históricas (también intentos fallidos identificados) y kit archivado.
- Se copió `entorno-blue-team/compose.yaml` sin cambios. Conserva digests,
  `juiceshop-h1`, redes, healthcheck, auditoría, rotación y `127.0.0.1:8081:8080`.
- Los dos scripts Python se añadieron a `scripts/` junto a `package.mjs`, sin
  reemplazarlo. El validador respeta el `.gitignore` oficial y verifica enlaces
  y anclas locales; el recolector exige salud de ambos contenedores, identidad
  de Juice Shop y evidencia del modo DetectionOnly.
- El README oficial se conserva completo y recibe una sección universitaria.
  Toda la guía académica queda en [GUIA-PROYECTO.md](GUIA-PROYECTO.md), con
  enlaces y clonación adaptados. El [README anterior exacto](fuentes/README-proyecto-anterior.txt)
  y su [.gitignore](fuentes/gitignore-proyecto-anterior.txt) son archivos de procedencia,
  no instrucciones vigentes de ejecución.
- `.gitignore` mantiene todas las reglas oficiales y añade exclusiones de
  secretos, temporales y ejecución del laboratorio. `package-lock.json` sigue
  ignorado por upstream; no se fuerza su inclusión ni se ocultan todas las
  claves o bases de datos de los retos oficiales.
- Se actualizaron PASTA II, reconocimiento, índice, checklist y referencias
  operativas. STRIDE, requisitos y DFD mantienen sus identificadores y modelo.
  Los tres archivos del DFD se conservan idénticos al origen.

## Docker y correspondencia del código

Desde el nuevo directorio se ejecutó `up -d --no-recreate --wait`: se reutilizaron
los contenedores saludables existentes. Sus etiquetas de creación conservan
la ruta anterior, pero Compose los identifica por `juiceshop-h1`; los hashes
de configuración de ambos servicios coinciden. No tienen bind mounts ni
build desde el proyecto anterior. Operar el laboratorio únicamente desde
`juice-shop-proyecto` a partir de ahora.

No se ejecutó `down`, `stop` ni recreación para cambiar etiquetas. Eso podría
perder datos efímeros/logs, y el arranque de Juice Shop recrea tablas SQLite.
El puerto 8080 del host sigue fuera del alcance; se conserva 8081 por el
conflicto documentado con EnterpriseDB y la autorización del propietario.

La imagen declara revisión `266448a`, compatible con el commit base. Los nueve
archivos del inventario de código se compararon por SHA-256 con blobs Git de
esa base y coinciden. Es una comprobación de esos archivos, no una prueba de
reproducibilidad de toda la imagen. Compose usa una imagen descargada por
digest: las futuras modificaciones H2 no se ejecutarán automáticamente.
Para H2 habrá que construir con el `Dockerfile` raíz y definir explícitamente
la imagen y versión de análisis. No usar `infrastructure/` para desplegar:
forma parte de los retos intencionalmente inseguros.

## Workflows oficiales: acción manual pendiente antes de publicar

Se conservan los **16 archivos** de `.github/workflows/`, sin editarlos,
renombrarlos ni eliminarlos. La consulta remota devolvió:

```json
{"enabled": true, "allowed_actions": "all", "sha_pinning_required": false}
{"total_count": 0, "workflows": []}
```

No hay workflows ni ejecuciones enumerados aún; eso **no acredita** que Actions
esté deshabilitado. No se cambiaron ajustes remotos durante esta migración.
Para H1, deshabilitar Actions en el **fork propio** antes del primer push:
[Settings → Actions → General](https://github.com/Gegdgt/juice-shop/settings/actions)
→ **Disable actions** → **Save**. Comprobar después `enabled=false`:

```powershell
gh api repos/Gegdgt/juice-shop/actions/permissions
```

Esta opción conserva todos los YAML. Si más adelante H2 necesita CI propia,
acordar su alcance, deshabilitar individualmente los workflows heredados que
GitHub enumere y después habilitar solo la automatización académica revisada.
El comando individual es `gh workflow disable NOMBRE.yml --repo Gegdgt/juice-shop`;
no se presume que funcione mientras la API no registre ese workflow.

| Archivo que debe permanecer inactivo en H1 | Función heredada |
|---|---|
| `ci.yml` | Tests/build y etapas de publicación/deploy condicionadas |
| `codeql-analysis.yml` | Análisis CodeQL |
| `frontend-bundle-analysis.yml` | Análisis del bundle de release |
| `image_actions.yml` | Compresión automática de imágenes |
| `issue-compliance.yml` | Gestión de cumplimiento de issues |
| `lint-fixer.yml` | Corrección automática y **auto-commit** ante push |
| `lock.yml` | Bloqueo de conversaciones |
| `pr-compliance.yml` | Gestión de cumplimiento de PR |
| `rebase.yml` | Rebase automático |
| `release.yml` | Releases e imágenes a partir de tags `v*` |
| `stale.yml` | Cierre de issues/PR inactivos |
| `update-challenges-ebook.yml` | Actualización de Companion Guide |
| `update-challenges-www-legacy.yml` | Actualización de retos en web OWASP anterior |
| `update-challenges-www.yml` | Actualización de retos en web actual |
| `update-news-www-legacy.yml` | Noticias de releases en web anterior |
| `update-news-www.yml` | Noticias de releases en web actual |

Algunos jobs comprueban `github.repository`, pero no todos los workflows lo
hacen. No copiar secretos de publicación ni confiar solo en esas condiciones.
La documentación de GitHub confirma la
[desactivación sin borrar archivos](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows)
y la [desactivación de Actions para un repositorio](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

## Publicación después de la revisión y autorización

Los siguientes comandos **no se han ejecutado**. Primero revisar los archivos,
deshabilitar Actions como se indica arriba y autorizar commit/push. Desde la
raíz del nuevo proyecto:

```powershell
git switch hito-1-integracion
git remote -v
git status --short
python .\scripts\validar-h1.py
python .\scripts\recopilar-evidencia-h1.py
git diff --check
git diff -- README.md .gitignore
# Añadir únicamente el alcance de H1, después de revisar también archivos nuevos.
git add -- README.md .gitignore docs/hito-1 entorno-blue-team scripts/validar-h1.py scripts/recopilar-evidencia-h1.py
git diff --cached --check
git diff --cached --stat
git diff --cached
# Solo tras autorización, con identidad Git correcta y sign-off DCO:
git commit -s -m "docs: integrar Hito 1 de Desarrollo Seguro en el fork"
git push -u origin hito-1-integracion
# PR exclusivamente dentro del fork propio; base master, nunca upstream:
gh pr create --repo Gegdgt/juice-shop --base master --head hito-1-integracion --web
```

`npm run lint` y `npm test` se intentaron: no pudieron iniciar las comprobaciones
por dependencias locales ausentes (`eslint` y `ng`). Resolver la instalación
de dependencias y repetirlos antes de un commit conforme a `AGENTS.md`.
No se modificaron fuentes de retos; RSN no aplica a esta migración.

## Continuidad H1–H4

Mantener el código oficial en la raíz, los entregables H1 en `docs/hito-1/`,
el laboratorio en `entorno-blue-team/` y scripts propios con nombres que indiquen
su hito. Los siguientes entregables podrán ir en `docs/hito-2/`, `docs/hito-3/`
y `docs/hito-4/` cuando se desarrollen; esas carpetas no se presentan como trabajo
completado. Integrar ramas académicas hacia `master` del fork tras revisión.
Consultar el [checklist](07-CHECKLIST.md) para el cierre académico pendiente.