# Fuentes, procedencia y uso de IA

## Material local preservado

El kit se inspeccionó completo antes de editar: Markdown, Compose, DOT, SVG y PNG. Se conservaron sus identificadores T-01 a T-13, RS-01 a RS-10 y CA-01 a CA-08; se ampliaron cuando el despliegue/código lo justificó. [Kit original](fuentes/kit-original.zip) y [README básico original](fuentes/README-raiz-original.md). El archivo ZIP es material de referencia, no la configuración que se debe ejecutar. [Manifiesto de integridad](fuentes/MANIFIESTO.json).

El README de comienzo del kit se conserva dentro del ZIP. Sus comandos de commit/push no son autorización para ejecutarlos. La documentación integrada y vigente está en el índice de H1.

La migración conserva el [README académico anterior completo](fuentes/README-proyecto-anterior.txt)
y su [.gitignore](fuentes/gitignore-proyecto-anterior.txt). El
[manifiesto de migración](fuentes/MANIFIESTO-MIGRACION.json) registra hashes de
los 29 archivos del proyecto origen, sin su `.git`. El manifiesto del kit
describe el contenido del ZIP, no los documentos académicos ya revisados.
La guía académica vigente está en [GUIA-PROYECTO.md](GUIA-PROYECTO.md).

## Referencias técnicas

Consultadas durante la preparación del 15–16 de noviembre de 2026. Las fuentes externas describen tecnologías/metodología; la ejecución concreta se acredita con evidencia local.

| Fuente | Aplicación |
|---|---|
| [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/) | Propósito educativo y aplicación intencionalmente vulnerable |
| [Guía oficial de ejecución](https://pwning.owasp-juice.shop/companion-guide/latest/part1/running.html) | Despliegue local |
| [Repositorio oficial](https://github.com/juice-shop/juice-shop) | Origen requerido del fork |
| [ModSecurity CRS Docker](https://github.com/coreruleset/modsecurity-crs-docker) | Variante Apache, PORT, BACKEND, DetectionOnly y variables de auditoría |
| [Docker: publicación de puertos](https://docs.docker.com/engine/network/port-publishing/) | Diferencia entre puerto interno y publicación loopback |
| [Docker Compose: redes](https://docs.docker.com/compose/how-tos/networking/) | DNS de servicios y redes |
| [Docker Desktop Windows](https://docs.docker.com/desktop/setup/install/windows-install/) | Requisitos del entorno |
| [PASTA — VerSprite](https://versprite.com/cybersecurity-listings/devsecops/pasta-threat-modeling/) | Etapas y análisis orientado al impacto; H1 aplica I–V |
| [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling) | Descomposición, amenazas y controles |
| [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) | Referencia para requisitos de autenticación, autorización, sesiones e inyecciones |
| [GitHub: fork](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/fork-a-repo) | Migración conservando upstream |

## Declaración de asistencia de IA — borrador para revisar

> Se utilizó ChatGPT/Codex como asistente para integrar el kit local, redactar y revisar documentación de PASTA I–IV y STRIDE, configurar Docker Compose y automatizar verificaciones locales. Se aportaron la solicitud del proyecto, archivos del kit y contexto del repositorio. Las verificaciones incluyen comandos reales y solicitudes HTTP normales; no se generaron capturas ficticias ni se ejecutó explotación. El equipo es responsable de revisar exactitud, citas, alcance autorizado y resultados antes de entregar.

**Pendiente de completar por el equipo:** nombres completos, fecha de revisión, modelo/interfaz si la guía lo exige, referencia al registro de conversación, apartados exactos asistidos y declaración en el formato requerido por UVG. No inventar el identificador de modelo utilizado.

**Limitación:** la guía UVG de uso de IA y la consigna original no están disponibles en el kit. Esta declaración no se certifica como conforme a ellas. Adjuntar o consultar la guía oficial y adaptar la cita antes de marcar ese requisito como cumplido. La IA no sustituye firma/revisión humana de Red y Blue Team.

**Asistencia durante la migración (16 de noviembre de 2026):** Codex ayudó a
copiar entregables al fork, fusionar documentación y exclusiones, adaptar los
scripts y verificar Docker/HTTP/WAF, hashes y enlaces. No realizó commit/push
ni cambió los ajustes remotos de Actions. La revisión humana sigue pendiente.

**Asistencia en la etapa V y los controles (16 de noviembre de 2026):** Claude
(Anthropic, modelo Claude Fable 5.2) leyó el código del fork y redactó la
[etapa V](03b-PASTA-5-Vulnerabilidades.md) y la tabla de controles por
requisito, corrigió los datos de integrantes y adaptó el entorno `waf-siem/`
del curso a Juice Shop. No ejecutó Docker, ataques, commits ni push. La
revisión humana sigue pendiente.
