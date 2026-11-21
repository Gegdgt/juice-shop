#!/usr/bin/env bash
# Prende o apaga las exclusiones de la ampliación del H3 (bloque ">>> H3-B" de
# waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf) y reinicia el WAF.
# Sirve para sacar la evidencia "antes" y "después" sin editar el archivo a mano.
# Uso, desde waf-siem/:  ./scripts/alternar-exclusiones.sh off   |   ./scripts/alternar-exclusiones.sh on
set -eu
cd "$(dirname "$0")/.."
ACCION="${1:-}"
case "$ACCION" in on|off) ;; *) echo "Uso: $0 on|off"; exit 1;; esac

python3 - "$ACCION" <<'PY'
import sys
accion = sys.argv[1]
ruta = 'waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf'
lineas = open(ruta).read().split('\n')
dentro, salida = False, []
for l in lineas:
    if l.startswith('# >>> H3-B'):
        dentro = True; salida.append(l); continue
    if l.startswith('# <<< H3-B'):
        dentro = False; salida.append(l); continue
    if dentro:
        if accion == 'off' and l.strip() and not l.lstrip().startswith('#'):
            l = '#OFF# ' + l
        elif accion == 'on' and l.startswith('#OFF# '):
            l = l[len('#OFF# '):]
    salida.append(l)
open(ruta, 'w').write('\n'.join(salida))
PY

docker compose restart waf >/dev/null
WAF_URL="${WAF_URL:-http://127.0.0.1:8080}"
for _ in $(seq 1 40); do
  c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WAF_URL/rest/admin/application-version" || true)"
  [ "$c" = "200" ] && break; sleep 1
done
echo "Exclusiones H3-B: $ACCION ($(grep -c '^#OFF# ' waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf) líneas apagadas)"
