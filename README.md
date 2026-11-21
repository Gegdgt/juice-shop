# Proyecto universitario UVG — Desarrollo Seguro

Este fork, [Gegdgt/juice-shop](https://github.com/Gegdgt/juice-shop), reúne el trabajo
de H1–H4 y conserva el código y la documentación oficial de OWASP Juice Shop.

- [Entregables H1: PASTA I–V, DFD, STRIDE y casos de abuso](docs/hito-1/README.md).
- [Diagramas por objetivo de negocio (ON-01 a ON-05)](docs/hito-1/02b-Diagramas-por-objetivo.md).
- [Hito 2: pipeline DevSecOps y PoC del Equipo rojo](docs/hito-2/README.md).
- [Hito 3: WAF, SIEM, reglas DET-01 a DET-05 y exclusiones](docs/hito-3/README.md).
- [Hito 4: correcciones en el código, pruebas de regresión y uso de IA](docs/hito-4/README.md).
- [Matriz de trazabilidad y riesgo residual (PASTA VI y VII)](docs/trazabilidad-y-riesgo-residual.md).
- Guiones del video: [H1 a H3 con demo en vivo](docs/guion-video.md) · [H4](docs/hito-4/guion-video.md).
- [Guía del proyecto, instalación, responsables y diagnóstico](docs/hito-1/GUIA-PROYECTO.md).
- [Checklist y requisitos pendientes](docs/hito-1/07-CHECKLIST.md).
- [Migración, workflows y publicación](docs/hito-1/08-Migracion-fork.md).
- [Resultados de la migración](docs/hito-1/evidencias/MIGRACION.md).

**Responsables:** Gegdgt (Red Team) y SebasJuarez (Blue Team). El grupo es de
dos integrantes.

Con Docker Desktop iniciado (contenedores Linux), ejecutar desde la raíz:

```powershell
docker compose -f .\entorno-blue-team\compose.yaml config --quiet
docker compose -f .\entorno-blue-team\compose.yaml up -d --wait
python .\scripts\validar-h1.py
python .\scripts\recopilar-evidencia-h1.py
```

Abrir **http://127.0.0.1:8081/**. La consigna solicita 8080, ocupado por
EnterpriseDB en este equipo; se conserva la alternativa autorizada 8081.
El WAF recibe en 8080 dentro del contenedor y opera en **DetectionOnly**:
inspecciona, sin prometer bloqueo. Juice Shop no publica su puerto 3000.
Este laboratorio usa imágenes fijadas por digest; no construye los cambios
locales del fork.
