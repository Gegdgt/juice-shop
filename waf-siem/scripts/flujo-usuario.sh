#!/usr/bin/env bash
# Usa Juice Shop como un cliente normal, de punta a punta, por el WAF.
# Con MODSEC_RULE_ENGINE=On, todo 403 aquí es un FALSO POSITIVO candidato:
# se busca en Kibana (fields.fuente : "waf-audit"), se lee el ruleId y se ajusta.
# Uso, desde waf-siem/:
#   ./scripts/flujo-usuario.sh | tee ../docs/hito-3/flujo-usuario.txt
set -u

WAF_URL="${WAF_URL:-http://127.0.0.1:8080}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BLOQUEOS=()
TOKEN=""

# pedir NOMBRE METODO RUTA [JSON]  -> deja el cuerpo en $TMP/body y el código en $CODE
pedir() {
  local nombre="$1" metodo="$2" ruta="$3" data="${4:-}"
  local args=(-s -o "$TMP/body" -w '%{http_code}' --max-time 20 -X "$metodo")
  [ -n "$TOKEN" ] && args+=(-H "Authorization: Bearer $TOKEN")
  [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "$data")
  CODE="$(curl "${args[@]}" "$WAF_URL$ruta" || echo 000)"
  marca=""
  if [ "$CODE" = "403" ]; then marca="  <-- 403: posible falso positivo"; BLOQUEOS+=("$(date '+%H:%M:%S') $metodo $ruta ($nombre)"); fi
  printf '%s | HTTP %s | %-6s %-45s | %s%s\n' "$(date '+%H:%M:%S')" "$CODE" "$metodo" "$ruta" "$nombre" "$marca"
  sleep 1
}
# extraer CAMPO -> primer valor de "CAMPO": en el último cuerpo
extraer() { grep -oE "\"$1\":\"?[^\",}]*" "$TMP/body" | head -1 | sed -E "s/\"$1\":\"?//"; }

INICIO_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
STAMP="$(date '+%Y%m%d%H%M%S')"
EMAIL="cliente.$STAMP@juice-sh.op"
PASS="Cliente.2026!"
PASS2="Cliente.2026!b"

echo "=== Flujo de usuario normal por el WAF ($WAF_URL) | inicio $(date '+%H:%M:%S') hora local ==="

# 1. Navegar sin sesión
pedir "Inicio (SPA)"            GET  "/"
pedir "Versión de la app"       GET  "/rest/admin/application-version"
pedir "Catálogo"                GET  "/api/Products"
pedir "Búsqueda normal"         GET  "/rest/products/search?q=jugo%20de%20manzana"
pedir "Preguntas de seguridad"  GET  "/api/SecurityQuestions/"

# 2. Registro y login
pedir "Registro"  POST "/api/Users" \
  "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"passwordRepeat\":\"$PASS\",\"securityQuestion\":{\"id\":2},\"securityAnswer\":\"Firulais\"}"
pedir "Login"     POST "/rest/user/login" "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}"
TOKEN="$(extraer token)"; BID="$(extraer bid)"
[ -z "$TOKEN" ] && { echo "No hubo token; el resto del flujo necesita sesión. Revisen el 403 de arriba."; }
pedir "Quién soy"  GET "/rest/user/whoami"
UID_="$(extraer id)"

# 3. Carrito
pedir "Agregar producto 1"   POST "/api/BasketItems" "{\"ProductId\":1,\"BasketId\":\"$BID\",\"quantity\":1}"
ITEM1="$(extraer id)"
pedir "Cambiar cantidad"     PUT  "/api/BasketItems/$ITEM1" '{"quantity":2}'
pedir "Agregar producto 2"   POST "/api/BasketItems" "{\"ProductId\":2,\"BasketId\":\"$BID\",\"quantity\":1}"
ITEM2="$(extraer id)"
pedir "Quitar producto 2"    DELETE "/api/BasketItems/$ITEM2"
pedir "Ver mi carrito"       GET  "/rest/basket/$BID"

# 4. Dirección y tarjeta (datos de prueba de la app local)
pedir "Nueva dirección" POST "/api/Addresss" \
  '{"country":"Guatemala","fullName":"Cliente Prueba","mobileNum":55512345,"zipCode":"01015","streetAddress":"6a avenida 12-34, zona 10","city":"Guatemala","state":"Guatemala"}'
ADDR="$(extraer id)"
pedir "Nueva tarjeta (de prueba)" POST "/api/Cards" \
  '{"fullName":"Cliente Prueba","cardNum":4111111111111111,"expMonth":12,"expYear":2090}'
CARD="$(extraer id)"

# 5. Reseña: crear y editar
MSG="Buen jugo, sabe a manzana de verdad. Lo volvería a comprar $STAMP"
pedir "Escribir reseña"  PUT "/rest/products/1/reviews" "{\"message\":\"$MSG\",\"author\":\"$EMAIL\"}"
pedir "Leer reseñas"     GET "/rest/products/1/reviews"
RID="$(tr '}' '\n' < "$TMP/body" | grep "$STAMP" | grep -oE '"_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
pedir "Editar reseña"    PATCH "/rest/products/reviews" "{\"id\":\"$RID\",\"message\":\"$MSG (editada: sigue igual de bueno)\"}"

# 6. Feedback con captcha
pedir "Captcha"          GET  "/rest/captcha/"
CID="$(extraer captchaId)"; ANS="$(extraer answer)"
pedir "Enviar feedback"  POST "/api/Feedbacks" \
  "{\"UserId\":$UID_,\"captchaId\":$CID,\"captcha\":\"$ANS\",\"comment\":\"La entrega fue rápida y el empaque venía bien. Gracias! (***${EMAIL#???})\",\"rating\":5}"

# 7. Queja con archivo adjunto
printf '%%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%%%EOF\n' > "$TMP/factura.pdf"
CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "Authorization: Bearer $TOKEN" \
  -F "file=@$TMP/factura.pdf;type=application/pdf" "$WAF_URL/file-upload" || echo 000)"
marca=""; [ "$CODE" = "403" ] && { marca="  <-- 403: posible falso positivo"; BLOQUEOS+=("$(date '+%H:%M:%S') POST /file-upload (Subir PDF)"); }
printf '%s | HTTP %s | %-6s %-45s | %s%s\n' "$(date '+%H:%M:%S')" "$CODE" POST "/file-upload" "Subir PDF de la queja" "$marca"; sleep 1
pedir "Enviar queja" POST "/api/Complaints" "{\"UserId\":$UID_,\"message\":\"Me llegó una botella abierta en el pedido, adjunto la factura.\"}"

# 8. Checkout
pedir "Métodos de entrega" GET  "/api/Deliverys"
pedir "Pagar (checkout)"   POST "/rest/basket/$BID/checkout" \
  "{\"couponData\":\"bnVsbA==\",\"orderDetails\":{\"paymentId\":\"$CARD\",\"addressId\":\"$ADDR\",\"deliveryMethodId\":\"1\"}}"
pedir "Historial de pedidos" GET "/rest/order-history"

# 9. Cambiar contraseña y volver a entrar
pedir "Cambiar contraseña" GET "/rest/user/change-password?current=$(printf %s "$PASS" | sed 's/!/%21/g')&new=$(printf %s "$PASS2" | sed 's/!/%21/g')&repeat=$(printf %s "$PASS2" | sed 's/!/%21/g')"
TOKEN=""
pedir "Login con la nueva" POST "/rest/user/login" "{\"email\":\"$EMAIL\",\"password\":\"$PASS2\"}"

echo
echo "Ventana para Kibana: desde $INICIO_UTC hasta $(date -u '+%Y-%m-%dT%H:%M:%SZ') (UTC)"
if [ ${#BLOQUEOS[@]} -eq 0 ]; then
  echo "Sin 403: ninguna acción legítima fue bloqueada."
else
  echo "403 en acciones legítimas (${#BLOQUEOS[@]}):"
  printf '  - %s\n' "${BLOQUEOS[@]}"
  echo "En Kibana (Discover, esa ventana): fields.fuente : \"waf-audit\" -> abran cada evento y lean"
  echo "modsec.transaction.messages.details.ruleId y data. El 949110 es el umbral: la exclusión va sobre la otra regla."
fi
