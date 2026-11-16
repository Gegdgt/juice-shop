# H1 — Diseño Seguro de OWASP Juice Shop

**UVG · Desarrollo Seguro · 2026.** Documentación integrada y entorno local comprobado. **Entrega académica aún pendiente.** Acceso autorizado: **http://127.0.0.1:8081/**, sustitución de 8080 aprobada por conflicto con EnterpriseDB.

| Entregable | Estado | Documento |
|---|---|---|
| PASTA I–II | Objetivos, activos, CIA y alcance preparados | [01](01-PASTA-1-2.md) |
| PASTA III | DFD actualizado con SQLite, MarsDB, logs y 4 límites | [02](02-PASTA-3-DFD.md) |
| PASTA IV | 16 amenazas, seis categorías STRIDE | [03](03-PASTA-4-STRIDE.md) |
| Requisitos/casos | 13 requisitos medibles y 12 casos completos de diseño | [04](04-Requisitos-y-casos-de-abuso.md) |
| Red Team | 7 rutas HTTP observadas; código inspeccionado; DevTools pendiente | [05](05-RedTeam-reconocimiento.md) |
| Blue Team | Dos contenedores saludables, WAF DetectionOnly observado | [06](06-BlueTeam-configuracion.md) |
| Checklist | Solo comprobaciones realizadas marcadas | [07](07-CHECKLIST.md) |
| Fork | Público y verificado; migración local realizada, publicación/Actions pendientes | [08](08-Migracion-fork.md) |
| Fuentes/IA | Procedencia conservada; conformidad UVG pendiente | [09](09-Fuentes-y-uso-IA.md) |
| Evidencias | Registros reales; capturas pendientes | [Índice](evidencias/README.md) |

**Roles:** Gegdgt — Red Team; Sebas Juárez — Blue Team. Faltan dos integrantes, previsiblemente uno por equipo según el kit. Falta confirmación contra la consigna original.

**Convenciones:** observado = evidencia técnica identificada; identificado en código = no implica ejecución; hipótesis = amenaza no explotada; propuesto = control todavía no validado; pendiente = requisito sin completar. [Resultados](evidencias/VERIFICACION.md).

El repositorio definitivo es [Gegdgt/juice-shop](https://github.com/Gegdgt/juice-shop),
fork público de `juice-shop/juice-shop`, con rama principal `master`.
La integración local está en `hito-1-integracion`; no se hicieron commits/push.
H2, H3 y H4 no se adelantaron. [Inicio e instalación](GUIA-PROYECTO.md),
[resultados de migración](evidencias/MIGRACION.md) y [README oficial](../../README.md).
