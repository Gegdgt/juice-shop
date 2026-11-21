#!/usr/bin/env bash
# Repite los PoC del Equipo rojo (H2) por el WAF y anota hora, payload y código HTTP.
# Sirve en los dos modos:
#   DetectionOnly -> los ataques pasan (200/401) pero quedan en Kibana (DET-01..05)
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
fila DET-03 PROPFIND /rest/products/search "método fuera de ALLOWED_METHODS" "$C"; sleep 2

# DET-04 · Path traversal / archivo restringido (CRS 930*). Ataque real sobre /ftp (V-10):
# el byte nulo codificado (%2500) engaña el filtro de extensiones de la app y descarga
# el respaldo package.json.bak. En DetectionOnly la app entrega el archivo (200).
P5="/ftp/package.json.bak%2500.md"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$WAF_URL$P5")"
fila DET-04 GET "$P5" "byte nulo: descarga package.json.bak" "$C"; sleep 2

# Misma técnica con otro respaldo. El CRS en paranoia 1 no tiene "coupons_2013" en su
# lista de archivos restringidos: sirve para ver qué se le escapa a DET-04.
P5B="/ftp/coupons_2013.md.bak%2500.md"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$WAF_URL$P5B")"
fila DET-04b GET "$P5B" "byte nulo: descarga coupons_2013.md.bak" "$C"; sleep 2

# DET-05 · Inyección de comandos (CRS 932*) en el parámetro de búsqueda.
P6="jugo; uname -a"
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" \
  --data-urlencode "q=$P6")"
fila DET-05 GET /rest/products/search "q=$P6" "$C"; sleep 2

P7='$(id)'
C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -G "$WAF_URL/rest/products/search" \
  --data-urlencode "q=$P7")"
fila DET-05 GET /rest/products/search "q=$P7" "$C"

echo
echo "Esperado en DetectionOnly: PoC-01 200, PoC-02 200, PoC-03 200, DET-02 200, DET-03 500 (la app no conoce PROPFIND),"
echo "                           DET-04 200 (se descarga el respaldo), DET-04b 200, DET-05 200 y 200 (la app solo busca texto)."
echo "Esperado en On:            PoC-01 403, PoC-02 403, PoC-03 200 (lo corrige el H4), DET-02 403, DET-03 403,"
echo "                           DET-04 403, DET-04b 200 (el CRS no lo marca en paranoia 1), DET-05 403 y 403."
echo "Con la app del H4 (build: ..) y DetectionOnly: PoC-01 401, PoC-02 200 sin datos, PoC-03 403: falla por el código."
