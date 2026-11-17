#!/usr/bin/env bash
# Lista las últimas transacciones del log de auditoría de ModSecurity con la regla
# que sumó puntos y el "data" (qué parámetro la disparó). Es lo mismo que se ve en
# Kibana, pero en la terminal: sirve para encontrar qué excluir.
# Uso, desde waf-siem/:  ./scripts/ver-bloqueos.sh [N]   (N = últimas N, por defecto 15)
set -u
N="${1:-15}"
docker compose exec -T waf cat /var/log/waf/modsec_audit.json | python3 -c '
import json, sys
n = int(sys.argv[1]); filas = []
for linea in sys.stdin:
    try: t = json.loads(linea)["transaction"]
    except Exception: continue
    req = t.get("request", {}); res = t.get("response", {})
    reglas = []
    for m in t.get("messages", []):
        d = m.get("details", {})
        if d.get("ruleId") in ("949110", "980170", "959100", "980140"): continue
        reglas.append("%s %s | data: %s" % (d.get("ruleId"), m.get("message", "")[:60], d.get("data", "")[:120]))
    filas.append((t.get("time_stamp", ""), res.get("http_code", "?"), req.get("method", ""), req.get("uri", "")[:90], reglas))
for ts, code, met, uri, reglas in filas[-n:]:
    print("%s | HTTP %s | %s %s" % (ts, code, met, uri))
    for r in reglas: print("    - " + r)
' "$N"
