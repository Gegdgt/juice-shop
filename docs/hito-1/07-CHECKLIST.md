# Checklist de entrega H1

Última revisión técnica: 16 de noviembre de 2026, America/Guatemala. Los checks acreditan preparación/verificación local, no firma del equipo ni entrega al docente. [Bitácora histórica](evidencias/VERIFICACION.md) y [verificación de migración](evidencias/MIGRACION.md).

## Configuración y procedencia

- [x] Directorio, estado inicial, remoto y rama inspeccionados antes de modificar; README original y kit conservados.
- [x] Destino `Gegdgt/juice-shop` público, `fork=true`, padre `juice-shop/juice-shop` y rama principal `master` comprobados.
- [x] Gegdgt (Red) y Sebas Juárez (Blue) documentados.
- [x] Grupo de dos integrantes: un Red Team y un Blue Team.
- [x] Entregables integrados localmente en `hito-1-integracion`, basada en `origin/master`.
- [x] Los 16 YAML oficiales de workflows se conservan sin cambios.
- [ ] Deshabilitar Actions en el fork antes de publicar y verificar `enabled=false`; actualmente la API devuelve `enabled=true` y cero workflows enumerados.
- [x] Compose válido: dos servicios, red interna privada y referencias por digest.
- [x] Arranque y respuesta HTTP real a través del WAF verificados en 8081, alternativa autorizada al puerto ocupado 8080.
- [x] Backend sin publicación al host; solo WAF publica 127.0.0.1:8081.
- [x] ModSecurity/CRS activo y DetectionOnly observado en evento real de solicitud normal.
- [x] Sin Elasticsearch/Kibana ni servicios de hitos futuros.

## Diseño seguro

- [x] PASTA I: propósito, activos, datos, CIA, impacto y prioridades.
- [x] PASTA II: tecnologías, actores, alcance y exclusiones.
- [x] PASTA III: entidades, procesos, SQLite/MarsDB, logs, flujos y LC-01 a LC-04 consistentes con Compose/código.
- [x] DOT/PNG/SVG actualizados; PNG revisado visualmente y exportaciones generadas desde el mismo DOT.
- [x] PASTA IV: 16 amenazas por componente con activo, impacto, mitigación y requisito; seis categorías STRIDE.
- [x] PASTA V: 10 debilidades identificadas por lectura de código, con CWE, amenaza y relación con el DFD; sin explotación.
- [x] Cada requisito indica el control que lo comprueba (pipeline, regla de Kibana o WAF).
- [x] 13 requisitos con criterio observable y estado real/propuesto.
- [x] 12 casos con precondiciones, Dado/Cuando/Entonces, resultado esperado y método de verificación.
- [x] Referencias T-xx ↔ RS-xx ↔ CA-xx comprobadas automáticamente.
- [ ] Revisión y aceptación conjunta de Red y Blue Team.

## Reconocimiento

- [x] Alcance local actualizado a 127.0.0.1:8081 por autorización del propietario.
- [x] Siete rutas GET normales observadas con fecha, resultado y fuente técnica.
- [x] Superficie adicional identificada por lectura de código, separada de ejecución real.
- [x] Hipótesis diferenciadas de vulnerabilidades confirmadas; sin explotación H1.
- [x] Tabla preparada para completar mediante DevTools.
- [ ] Navegación visual y capturas de catálogo, formularios, login, carrito y pedido propio.
- [ ] Confirmar parámetros y comportamiento autenticado con cuenta ficticia y navegación ordinaria.

## Evidencias y entrega

- [x] Evidencia técnica real y errores registrados sin afirmar resultados inexistentes.
- [x] Fragmentos exportados sanitizados; no bases de datos, JWT, claves privadas ni credenciales de cuentas en evidencias finales.
- [x] README reproducible, referencias y diagnóstico incluidos.
- [x] Enlaces relativos y estructura verificados por script.
- [x] .gitignore permite documentación, diagramas, evidencia sanitizada, Compose y fuentes; se conserva la exclusión oficial de `package-lock.json`.
- [x] git status, diff y revisión final local realizados; sin commit ni push.
- [x] Migración al fork realizada; proyecto original intacto y README oficial conservado.
- [x] Borrador de declaración de asistencia IA preparado.
- [ ] Adaptar declaración a la guía oficial UVG y contrastar la rúbrica completa.
- [ ] Tomar/revisar capturas reales y completar sus metadatos.
- [ ] Fusionar `hito-1-integracion` en `master` después de la revisión conjunta.
- [ ] Instalar dependencias locales y repetir `npm run lint` y `npm test` antes del commit: intentados, detenidos por ausencia de `eslint` y `ng`.

## Repetir validación

```powershell
python .\scripts\validar-h1.py
docker compose -f .\entorno-blue-team\compose.yaml config
docker compose -f .\entorno-blue-team\compose.yaml up -d
docker compose -f .\entorno-blue-team\compose.yaml ps
python .\scripts\recopilar-evidencia-h1.py
git status --short
git diff --check
```

Estado de seguridad: RS-08 y RS-12 comprobados; RS-06/RS-10 parciales; controles funcionales restantes propuestos para hitos posteriores. Este checklist no acredita remediación ni cierre completo de H1 académico.
