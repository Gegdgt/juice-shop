#!/usr/bin/env bash
# Saca toda la evidencia de la ampliación del H3 (DET-04, DET-05 y exclusiones 10003/10004)
# en una sola corrida y la deja en docs/hito-3/ con sufijo -2. No borra la evidencia original.
#
# Requisitos: el entorno levantado con la imagen pública de Juice Shop (sin COMPOSE_FILE del H4)
# y Kibana arriba. Uso, desde waf-siem/:
#   ./scripts/evidencia-h3b.sh
#
# Pasos:
#   1. WAF en DetectionOnly -> poc-redteam.sh          -> poc-DetectionOnly-2.txt
#   2. WAF en On            -> poc-redteam.sh          -> poc-On-2.txt
#   3. Exclusiones H3-B off -> flujo-usuario.sh        -> flujo-usuario-antes-2.txt
#                              ver-bloqueos.sh         -> bloqueos-antes-2.txt
#   4. Exclusiones H3-B on  -> flujo-usuario.sh        -> flujo-usuario-despues-2.txt
#                              poc-redteam.sh          -> poc-On-exclusiones-2.txt
# Al final el WAF queda en On con las exclusiones prendidas.
set -u
cd "$(dirname "$0")/.."
DOCS=../docs/hito-3

if [ -n "${COMPOSE_FILE:-}" ]; then
  echo "AVISO: COMPOSE_FILE=$COMPOSE_FILE. Esta evidencia es del H3 y va con la imagen pública."
  echo "       Corran 'unset COMPOSE_FILE && docker compose up -d app' y vuelvan a intentar."
  exit 1
fi

echo "== 1/4 DetectionOnly: ataques pasan y quedan en Kibana"
./scripts/modo-waf.sh DetectionOnly
./scripts/poc-redteam.sh | tee "$DOCS/poc-DetectionOnly-2.txt"

echo; echo "== 2/4 On: ataques bloqueados"
./scripts/modo-waf.sh On
./scripts/poc-redteam.sh | tee "$DOCS/poc-On-2.txt"

echo; echo "== 3/4 On sin las exclusiones nuevas: falsos positivos"
./scripts/alternar-exclusiones.sh off
./scripts/flujo-usuario.sh | tee "$DOCS/flujo-usuario-antes-2.txt"
sleep 3
./scripts/ver-bloqueos.sh 40 | tee "$DOCS/bloqueos-antes-2.txt"

echo; echo "== 4/4 On con las exclusiones: flujo limpio y ataques siguen bloqueados"
./scripts/alternar-exclusiones.sh on
./scripts/flujo-usuario.sh | tee "$DOCS/flujo-usuario-despues-2.txt"
./scripts/poc-redteam.sh | tee "$DOCS/poc-On-exclusiones-2.txt"

echo
echo "Listo. Archivos en docs/hito-3/: poc-DetectionOnly-2.txt, poc-On-2.txt,"
echo "flujo-usuario-antes-2.txt, bloqueos-antes-2.txt, flujo-usuario-despues-2.txt, poc-On-exclusiones-2.txt"
echo "Siguiente: ./scripts/kibana-reglas.sh y las capturas 09 a 12 (docs/hito-3/README.md)."
