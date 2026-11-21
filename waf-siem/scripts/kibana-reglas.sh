#!/usr/bin/env bash
# Importa las búsquedas guardadas DET-04 y DET-05 en Kibana y vuelve a exportar
# todos los objetos (reglas DET-*, data view y dashboard) a kibana-export.ndjson.
# Es lo mismo que Stack Management -> Saved Objects -> Import / Export, por API.
# Uso, desde waf-siem/:  ./scripts/kibana-reglas.sh
set -eu
cd "$(dirname "$0")/.."
KIBANA="${KIBANA_URL:-http://127.0.0.1:5601}"

echo "Importando DET-04 y DET-05..."
curl -s -X POST "$KIBANA/api/saved_objects/_import?overwrite=true" \
  -H 'kbn-xsrf: true' --form file=@kibana-det-04-05.ndjson
echo

echo "Exportando todos los objetos a kibana-export.ndjson..."
curl -s -X POST "$KIBANA/api/saved_objects/_export" \
  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  -d '{"type":["search","dashboard","index-pattern"],"includeReferencesDeep":true}' \
  -o kibana-export.ndjson
python3 -c "
import json
for l in open('kibana-export.ndjson'):
    o = json.loads(l)
    if o.get('type'): print(' ', o['type'], '-', o.get('attributes', {}).get('title'))
"
