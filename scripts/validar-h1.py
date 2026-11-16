"""Valida documentos, trazabilidad y Compose H1 sin tráfico ofensivo."""
import json
import pathlib
import re
import subprocess
import sys
from urllib.parse import unquote

sys.stdout.reconfigure(encoding='utf-8')

ROOT = pathlib.Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs/hito-1'
errors, checks = [], []


def check(condition, message):
    (checks if condition else errors).append(message)


def run(args):
    return subprocess.run(args, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=30)


required = ['README.md', '.gitignore', 'entorno-blue-team/compose.yaml',
            'docs/hito-1/README.md', 'docs/hito-1/GUIA-PROYECTO.md',
            'docs/hito-1/evidencias/README.md', 'scripts/package.mjs']
required += ['docs/hito-1/DFD-referencia.' + ext for ext in ('dot', 'svg', 'png')]
for name in required:
    check((ROOT / name).is_file(), 'Archivo requerido: ' + name)
check(len(list(DOCS.glob('0[1-9]-*.md'))) == 9, 'Nueve documentos académicos numerados')
link_count = 0
for p in [ROOT / 'README.md', *DOCS.rglob('*.md')]:
    text = re.sub(r'```.*?```', '', p.read_text(encoding='utf-8'), flags=re.S)
    for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text):
        if re.match(r'^[a-zA-Z]+:', target) or target.startswith('//'):
            continue
        target, _, fragment = unquote(target.strip('<>')).partition('#')
        dest = p.parent / target if target else p
        link_count += 1
        check(dest.exists(), f'Enlace {p.relative_to(ROOT)} → {target or "#" + fragment}')
        if fragment and dest.is_file() and dest.suffix == '.md':
            body = re.sub(r'```.*?```', '', dest.read_text(encoding='utf-8'), flags=re.S)
            anchors, seen = set(re.findall(r'(?:id|name)="([^"]+)"', body)), {}
            for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', body, re.M):
                heading = re.sub(r'!?\[([^\]]*)\]\([^)]+\)', r'\1', heading)
                slug = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
                count = seen.get(slug, 0)
                anchors.add(slug + (f'-{count}' if count else ''))
                seen[slug] = count + 1
            check(fragment in anchors, f'Ancla {p.name} → {target}#{fragment}')

threat_text = (DOCS / '03-PASTA-4-STRIDE.md').read_text(encoding='utf-8')
req_text = (DOCS / '04-Requisitos-y-casos-de-abuso.md').read_text(encoding='utf-8')
rows = [line for line in threat_text.splitlines() if re.match(r'\| T-\d+', line)]
threats = {re.search(r'T-\d+', row)[0] for row in rows}
requirements = set(re.findall(r'^\| (RS-\d+) \|', req_text, re.M))
cases = dict(re.findall(r'^### (CA-\d+) — ([\s\S]*?)(?=^### |\Z)', req_text, re.M))
check(len(threats) == len(rows), 'IDs de amenaza únicos')
check(len(requirements) >= 10, f'{len(requirements)} requisitos (mínimo 10)')
check(len(cases) >= 5, f'{len(cases)} casos (mínimo 5)')
check({row.split('|')[3].strip() for row in rows} == set('STRIDE'), 'Seis categorías STRIDE')
for cid, body in cases.items():
    for field in ['**Amenazas:**', '**Requisitos:**', '**Precondiciones:**', '**Dado**', '**Cuando**', '**Entonces**', '**Resultado de seguridad esperado:**', '**Verificación posterior:**', '**Estado:**']:
        check(field in body, f'{cid}: {field}')
    for tid in re.findall(r'T-\d+', body):
        check(tid in threats, f'{cid} referencia amenaza {tid}')
    for rid in re.findall(r'RS-\d+', body):
        check(rid in requirements, f'{cid} referencia requisito {rid}')
for row in rows:
    tid = re.search(r'T-\d+', row)[0]
    for rid in re.findall(r'RS-\d+', row):
        check(rid in requirements, f'{tid} referencia {rid}')
    for cid in re.findall(r'CA-\d+', row):
        check(cid in cases and tid in cases[cid], f'Trazabilidad inversa {tid} ↔ {cid}')
        for rid in re.findall(r'RS-\d+', row):
            check(rid in cases.get(cid, ''), f'{tid} / {cid} comparten {rid}')
for rid in requirements:
    check(any(rid in row for row in rows), f'{rid} tiene amenaza')
    check(any(rid in body for body in cases.values()), f'{rid} tiene caso')

compose = run(['docker', 'compose', '-f', 'entorno-blue-team/compose.yaml', 'config', '--format', 'json'])
check(compose.returncode == 0, 'Docker Compose config válido')
if compose.returncode == 0:
    c = json.loads(compose.stdout)
    services = c['services']
    check(set(services) == {'juice-shop', 'waf'}, 'Dos servicios, sin SIEM')
    check(not services['juice-shop'].get('ports'), 'Backend sin ports')
    ports = services['waf'].get('ports', [])
    check(len(ports) == 1 and ports[0]['host_ip'] == '127.0.0.1' and str(ports[0]['published']) == '8081' and ports[0]['target'] == 8080, 'WAF solo 127.0.0.1:8081 → 8080')
    check(c['networks']['interna'].get('internal') is True, 'Red interna aislada')
    check(set(services['juice-shop']['networks']) == {'interna'}, 'Backend solo red interna')
    check(services['waf']['environment']['MODSEC_RULE_ENGINE'] == 'DetectionOnly', 'WAF DetectionOnly')
    check(services['waf']['environment']['BACKEND'] == 'http://juice-shop:3000', 'Backend coincide con DFD')
    check(all(re.search(r'@sha256:[a-f0-9]{64}$', x['image']) for x in services.values()), 'Imágenes fijadas por digest')
dot = (DOCS / 'DFD-referencia.dot').read_text(encoding='utf-8-sig')
for marker in ['127.0.0.1:8081', 'LC-01', 'LC-02', 'LC-03', 'LC-04', 'SQLite', 'MarsDB', 'Logs Docker', 'F12']:
    check(marker in dot, 'DFD contiene ' + marker)

candidates = [p.relative_to(ROOT).as_posix() for p in DOCS.rglob('*') if p.is_file()]
candidates += ['README.md', 'entorno-blue-team/compose.yaml', 'scripts/validar-h1.py', 'scripts/recopilar-evidencia-h1.py', 'scripts/package.mjs', 'src/example.ts', '.env.example', 'encryptionkeys/example.key', 'data/static/example.db']
for name in candidates:
    check(run(['git', 'check-ignore', '--no-index', '-q', name]).returncode == 1, 'Versionable: ' + name)
for name in ['package-lock.json', '.env', '.env.local', 'node_modules/example/index.js', 'entorno-blue-team/runtime/session.db', 'entorno-blue-team/logs/access.log', 'docs/hito-1/evidencias/privado/session.har', 'secrets/example.key', 'scripts/__pycache__/validar-h1.pyc']:
    check(run(['git', 'check-ignore', '--no-index', '-q', name]).returncode == 0, 'Ignorado: ' + name)
origin = run(['git', 'remote', 'get-url', 'origin'])
check(origin.returncode == 0 and origin.stdout.strip().removesuffix('.git') in
      {'https://github.com/Gegdgt/juice-shop', 'git@github.com:Gegdgt/juice-shop'},
      'origin corresponde al fork Gegdgt/juice-shop')
check(run(['git', 'diff', '--check']).returncode == 0, 'git diff --check')
print(json.dumps({'comprobaciones_ok': len(checks), 'enlaces_locales': link_count, 'amenazas': len(threats),
                  'requisitos': len(requirements), 'casos': len(cases), 'errores': errors}, ensure_ascii=False, indent=2))
sys.exit(1 if errors else 0)
