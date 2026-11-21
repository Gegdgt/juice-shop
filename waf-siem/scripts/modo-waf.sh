#!/usr/bin/env bash
# Cambia el modo del WAF en .env (MODSEC_RULE_ENGINE) y recrea SOLO el contenedor del WAF.
# Uso, desde waf-siem/:  ./scripts/modo-waf.sh DetectionOnly   |   ./scripts/modo-waf.sh On
# --no-deps: no toca la app. Si están en el H4 (COMPOSE_FILE con docker-compose.h4.yml),
# la app construida desde el código sigue corriendo.
set -eu
cd "$(dirname "$0")/.."
MODO="${1:-}"
case "$MODO" in DetectionOnly|On) ;; *) echo "Uso: $0 DetectionOnly|On"; exit 1;; esac

python3 - "$MODO" <<'PY'
import re, sys
modo = sys.argv[1]
s = open('.env').read()
s, n = re.subn(r'(?m)^MODSEC_RULE_ENGINE=.*$', 'MODSEC_RULE_ENGINE=' + modo, s)
if n == 0:
    s += '\nMODSEC_RULE_ENGINE=' + modo + '\n'
open('.env', 'w').write(s)
PY

docker compose up -d --no-deps waf >/dev/null
WAF_URL="${WAF_URL:-http://127.0.0.1:8080}"
for _ in $(seq 1 40); do
  c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WAF_URL/rest/admin/application-version" || true)"
  [ "$c" = "200" ] && break; sleep 1
done
echo "WAF en $MODO ($(docker compose exec -T waf printenv MODSEC_RULE_ENGINE 2>/dev/null || echo '?'))"
