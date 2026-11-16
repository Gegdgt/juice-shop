# Hito 2 · Pipeline y ataque

**Estado:** pipeline adaptado, pendiente de su primera corrida. PoC del Equipo rojo pendientes.

## Pipeline

- Workflow: [`.github/workflows/devsecops.yml`](../../.github/workflows/devsecops.yml), adaptado de la plantilla del curso.
- Corrida de evidencia (enlace a GitHub Actions): *pendiente; pegar aquí el enlace de la primera corrida completa.*
- Modo del gate: `reporte`.
- Workflows originales: los 16 del proyecto se movieron, sin editarlos, a [`.github/workflows-upstream/`](../../.github/workflows-upstream/README.md). GitHub Actions solo ejecuta lo que está en `.github/workflows/`, así que quedan deshabilitados.

### Qué se adaptó a Juice Shop

Se conservan los cuatro jobs, el gate y los artefactos de la plantilla.

| Job | Cambio | Por qué |
|---|---|---|
| SAST | Ninguno | Semgrep recorre el árbol de archivos; no depende de npm |
| SCA | Genera los lockfiles en el runner y audita dos proyectos: el servidor (raíz) y `frontend/`. El gate suma high y critical leyendo los dos JSON | El repo no versiona `package-lock.json` (`.npmrc`: `package-lock=false`) y `npm audit` lo exige. Se usa npm 11.19.1, el del CI original: con npm 10 falla el lockfile del frontend |
| SBOM | Genera los lockfiles antes de correr Syft | Sin lockfile, Syft no ve las dependencias npm |
| DAST | Construye la imagen con el `Dockerfile` del fork, la levanta en el puerto 3000 y espera dos URL antes de escanear | El escaneo corre sobre el código de este repositorio, no sobre la imagen pública, y así verá las correcciones del Hito 4. El 8080 es el del WAF y no se usa en el runner |

### Umbral del gate y justificación

Propuesta del Equipo azul, pendiente de acordar entre los dos.

| Control | Herramienta | Umbral | Qué hicieron con los hallazgos |
|---|---|---|---|
| SAST | Semgrep (`p/default` y `p/owasp-top-ten`) | 0 hallazgos de severidad ERROR | Pendiente de la primera corrida. Revisar si aparecen V-01 y V-02 de la [etapa V](../hito-1/03b-PASTA-5-Vulnerabilidades.md) |
| SCA | `npm audit`, solo dependencias de producción | 0 vulnerabilidades high o critical | Línea base medida en local el 16 de noviembre de 2026 con los mismos comandos: servidor 12 high y 6 critical; frontend 1 high. Se confirma con el artefacto `sca` |
| SBOM | Syft, CycloneDX | El artefacto `sbom.cdx.json` se publica | Inventario de componentes; no tiene umbral |
| DAST | ZAP baseline | 0 alertas de riesgo alto | Pendiente de la primera corrida |

**Por qué `reporte` y no `bloqueo`.** Juice Shop es vulnerable a propósito. Con 19 dependencias high o critical de línea base, el modo `bloqueo` dejaría el pipeline en rojo en cada push sin decir nada nuevo. En `reporte` los controles corren, publican sus reportes y el pipeline solo falla si una herramienta no puede ejecutarse. Los umbrales quedan escritos para el Hito 4: una corrección no debe sumar hallazgos sobre esta línea base.

**Uso de IA.** El workflow se adaptó con Claude (Anthropic, modelo Claude Fable 5.2) a partir de la plantilla del curso. Los comandos de SCA se probaron en local; los jobs de SAST, SBOM y DAST no se han ejecutado todavía. El grupo revisa el diff antes de darlo por bueno.

## PoC del Equipo rojo

*Instrucción: mismo método del laboratorio DAST, con el WAF en DetectionOnly y
el proxy apuntando a `http://localhost:8080`. Primero ZAP (explorar, escanear y
guardar el reporte). Después Burp Repeater (petición y respuesta de cada
hallazgo). Luego OWASP Top 10:2025, CWE y el vector CVSS v3.1 completo.
Postman repite el PoC ya confirmado, con la hora anotada, para el Equipo azul.
Al menos tres vulnerabilidades de la app.*

- Reporte de ZAP (archivo en esta carpeta):

| ID | Vulnerabilidad | Dónde (método y ruta por :8080) | OWASP Top 10:2025 | CWE | Vector CVSS v3.1 | Puntaje |
|---|---|---|---|---|---|---|
| PoC-01 |  |  |  |  |  |  |
| PoC-02 |  |  |  |  |  |  |
| PoC-03 |  |  |  |  |  |  |

### PoC-01

- Alerta de ZAP (nombre y URL del reporte):
- Captura de Burp Repeater (petición y respuesta):
- Cómo repetirlo en Postman:
- Resultado observado:
- Justificación del CVSS, métrica por métrica:

### PoC-02

- Alerta de ZAP (nombre y URL del reporte):
- Captura de Burp Repeater (petición y respuesta):
- Cómo repetirlo en Postman:
- Resultado observado:
- Justificación del CVSS, métrica por métrica:

### PoC-03

- Alerta de ZAP (nombre y URL del reporte):
- Captura de Burp Repeater (petición y respuesta):
- Cómo repetirlo en Postman:
- Resultado observado:
- Justificación del CVSS, métrica por métrica:

## Registro de ataques

*Instrucción: una fila por intento, no solo por vulnerabilidad. Sirve para la
línea de tiempo del informe. Usen solo cuentas de prueba. En Herramienta
escriban ZAP, Burp o Postman según el intento. Cada vulnerabilidad lleva una
fila de ZAP, una de Burp y otra de la repetición en Postman.*

| Fecha | Hora | Quién | Herramienta | Método y ruta | Payload | Respuesta |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |
