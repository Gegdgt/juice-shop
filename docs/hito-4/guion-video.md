# Guion del video · Hito 4 (corrección)

Complementa el [video de H1 a H3](../guion-video.md): cierra la demo de PoC-02 con la corrección en el código y agrega las otras dos correcciones. Duración pensada: 4 a 5 minutos.

**Antes de grabar:** construir la imagen del H4 para no esperar en vivo (desde `waf-siem/`):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.h4.yml docker compose build app
```

## Demo del Hito 4 · Remediación con IA

- Los commits en GitHub, en orden: primero `test(h4)`, después los tres `fix(h4)`.
- Uno de los diffs (el del carrito es el más corto): `where: { id, UserId: sessionUser.data.id }`.
- La prueba de regresión en terminal, antes y después:
  ```bash
  git checkout <hash de test(h4)> -- routes && node --import ./test/api/helpers/test-env.mjs --import tsx --test --test-force-exit test/api/h4-regression.test.ts   # 9 fallan
  git checkout HEAD -- routes && node --import ./test/api/helpers/test-env.mjs --import tsx --test --test-force-exit test/api/h4-regression.test.ts           # 14 pasan
  ```
  (Si no quieren correrlo en vivo, muestren `regresion-antes.txt` y `regresion-despues.txt`.)
- Re-prueba con la app nueva y el WAF en `DetectionOnly`:
  ```bash
  export COMPOSE_FILE=docker-compose.yml:docker-compose.h4.yml
  docker compose up -d app
  ./scripts/modo-waf.sh DetectionOnly
  ./scripts/reprueba-h4.sh
  ```
  PoC-01 → 401, PoC-02 → 200 vacío, PoC-03 → 403 con el JSON de la app. Muestren en Kibana que DET-01 sigue viendo PoC-01 y PoC-02: el WAF detecta, el código corrige.
- Uso de IA: herramienta, el prompt, qué se aceptó y qué se descartó (`ia/registro-ia.md`), y la auditoría (Semgrep antes y después, sin dependencias nuevas, sin secretos).


Al terminar de grabar, dejen el entorno como estaba: `unset COMPOSE_FILE && docker compose up -d app && ./scripts/modo-waf.sh On`.
