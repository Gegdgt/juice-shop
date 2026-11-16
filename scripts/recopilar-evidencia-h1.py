"""Reconocimiento pasivo de H1. Solo GET locales; no autenticación ni explotación."""
import datetime as dt
import hashlib
import json
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/hito-1/evidencias'
COMPOSE = ['docker', 'compose', '-f', 'entorno-blue-team/compose.yaml']
BASE = 'http://127.0.0.1:8081'
TZ = dt.timezone(dt.timedelta(hours=-6), 'America/Guatemala')
sys.stdout.reconfigure(encoding='utf-8')


def now():
    return dt.datetime.now(TZ).isoformat(timespec='seconds')


def command(args):
    try:
        result = subprocess.run(args, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=30)
    except subprocess.TimeoutExpired:
        return {'fecha': now(), 'argv': args, 'exit_code': 124, 'stdout': '', 'stderr': 'Tiempo límite de 30 s excedido'}
    return {'fecha': now(), 'argv': args, 'exit_code': result.returncode,
            'stdout': result.stdout.strip(), 'stderr': result.stderr.strip()}


def main():
    report = {'fecha': now(), 'destino_autorizado': BASE,
              'metodo': 'Inspección Docker, lectura de código empaquetado y GET normales sin cookies. No se guardan cuerpos ni cabeceras sensibles.',
              'comandos': [], 'http': []}
    commands = [
        ['git', 'remote', '-v'], ['git', 'branch', '--show-current'], ['git', 'rev-parse', 'HEAD'],
        ['docker', 'version', '--format', '{{json .}}'], ['docker', 'compose', 'version'],
        COMPOSE + ['config'], COMPOSE + ['ps', '--format', 'json'],
        ['docker', 'inspect', 'juiceshop-h1-juice-shop-1', 'juiceshop-h1-waf-1', '--format',
         '{{json .Name}} {{json .State.Status}} {{json .NetworkSettings.Ports}} {{json .HostConfig.PortBindings}}'],
        ['docker', 'network', 'inspect', 'juiceshop-h1_interna', '--format', '{{json .Internal}} {{json .Containers}}'],
        COMPOSE + ['exec', '-T', 'waf', 'httpd', '-t'],
        COMPOSE + ['exec', '-T', 'waf', 'httpd', '-M'],
        COMPOSE + ['exec', '-T', 'waf', 'cat', '/etc/modsecurity.d/modsecurity.conf', '/etc/modsecurity.d/modsecurity-override.conf'],
    ]
    for args in commands:
        item = command(args)
        if args[-2:] == ['/etc/modsecurity.d/modsecurity.conf', '/etc/modsecurity.d/modsecurity-override.conf']:
            item['stdout'] = '\n'.join(l for l in item['stdout'].splitlines() if l.startswith(('SecRuleEngine', 'SecAudit', 'SecRequestBody', 'SecResponseBody')))
            item['seleccion'] = 'Solo directivas de motor/auditoría/cuerpos, sin comentarios.'
        report['comandos'].append(item)
    state = command(COMPOSE + ['ps', '--all', '--format', 'json'])
    report['comandos'].append(state)
    containers = [json.loads(line) for line in state['stdout'].splitlines()] if state['exit_code'] == 0 else []
    report['salud'] = [{'servicio': c['Service'], 'estado': c['State'], 'salud': c.get('Health')}
                       for c in containers]
    js = r"""const fs=require('fs'),crypto=require('crypto');
const specs={
 'server.ts':/app\.(get|post|put|delete|use)\(['\"]\/(rest\/(user\/login|user\/whoami|products\/search|basket|order-history|track-order|captcha|languages|admin\/application-version)|api\/(BasketItems|Users|Feedbacks))|sequelize\.sync|nosql|new finale/i,
 'models/index.ts':/sqlite|storage|Sequelize/,
 'lib/insecurity.ts':/jwt\.sign|expiresIn|Authorization|Bearer/,
 'data/mongodb.ts':/mars|Collection|orders|reviews/,
 'routes/search.ts':/req\.query|sequelize\.query/,
 'routes/login.ts':/authentication:|bid: basket.id|models.sequelize.query/,
 'frontend/src/app/app.routing.ts':/path:.*(login|register|search|basket|order|contact)/,
 'frontend/src/app/Services/basket.service.ts':/this\.http|quantity|ProductId|BasketId/,
 'frontend/src/app/Services/user.service.ts':/this\.http|login|email|password/};
const out={version:require('./package.json').version,node:process.version,files:[]};
for(const [p,re] of Object.entries(specs)){if(fs.existsSync(p)){const s=fs.readFileSync(p,'utf8');out.files.push({path:p,sha256:crypto.createHash('sha256').update(s).digest('hex'),lines:s.split('\n').flatMap((v,i)=>re.test(v)?[{line:i+1,text:v}]:[])});}else{out.files.push({path:p,estado:'No existe en esta imagen'});}}
console.log(JSON.stringify(out));"""
    source = command(COMPOSE + ['exec', '-T', 'juice-shop', '/nodejs/bin/node', '-e', js])
    # Conservar el código de selección y fragmentos públicos, nunca bases de datos o claves.
    report['codigo'] = source
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    # Rutas de solo lectura verificadas previamente en server.ts; robots es recurso convencional.
    for path in ['/', '/robots.txt', '/rest/products/search?q=apple', '/rest/user/whoami',
                 '/rest/languages', '/rest/captcha', '/rest/admin/application-version']:
        req = urllib.request.Request(BASE + path, headers={'User-Agent': 'H1-Recon-Pasivo/1.0'})
        item = {'fecha': now(), 'metodo': 'GET', 'url': BASE + path, 'sesion': 'Sin credenciales ni cookies'}
        try:
            with opener.open(req, timeout=15) as res:
                body = res.read()
                item.update(status=res.status, content_type=res.headers.get('Content-Type'),
                            bytes=len(body), sha256=hashlib.sha256(body).hexdigest(), server=res.headers.get('Server'))
                if 'json' in (item['content_type'] or ''):
                    obj = json.loads(body)
                    item['claves_raiz'] = list(obj) if isinstance(obj, dict) else ['array']
                    if isinstance(obj, dict) and isinstance(obj.get('data'), list):
                        item['numero_elementos'] = len(obj['data'])
                        if obj['data'] and isinstance(obj['data'][0], dict):
                            item['campos_primer_elemento'] = list(obj['data'][0])
                elif path == '/':
                    item['contiene_juice_shop'] = b'Juice Shop' in body
                elif path == '/robots.txt':
                    item['contenido_publico'] = body.decode('utf-8', errors='replace')[:2000]
        except Exception as exc:
            item['error'] = str(exc)
        report['http'].append(item)
    log = command(COMPOSE + ['logs', '--no-color', '--since', '3m', 'waf'])
    selected = []
    for line in log['stdout'].splitlines():
        if '| {' not in line:
            continue
        try:
            event = json.loads(line.split('| ', 1)[1])
            audit = event.get('audit_data', {})
            if audit.get('handler') != 'proxy-server':
                continue
            selected.append({'transaction': event.get('transaction'),
                             'handler': audit.get('handler'), 'engine_mode': audit.get('engine_mode'),
                             'producer': audit.get('producer'),
                             'regla_host_numerico': any('[id "920350"]' in m for m in audit.get('messages', []))})
        except (ValueError, IndexError):
            continue
    report['waf'] = {'fecha': log['fecha'], 'argv': log['argv'], 'exit_code': log['exit_code'],
                     'seleccion': 'Últimos 7 eventos proxy; solo metadatos permitidos, sin payloads, cabeceras, cookies o mensajes crudos.',
                     'eventos': selected[-7:]}
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / ('verificacion-' + dt.datetime.now(TZ).strftime('%Y%m%d-%H%M%S') + '.json')
    dest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(dest.relative_to(ROOT))
    print(json.dumps({'http': report['http'], 'eventos_waf': len(selected)}, ensure_ascii=False, indent=2))
    ok = all(c['exit_code'] == 0 for c in report['comandos']) and source['exit_code'] == 0
    ok = ok and {c['servicio'] for c in report['salud']} == {'juice-shop', 'waf'}
    ok = ok and all(c['estado'] == 'running' and c['salud'] == 'healthy' for c in report['salud'])
    ok = ok and all(h.get('status') == 200 for h in report['http'])
    ok = ok and report['http'][0].get('contiene_juice_shop') is True
    ok = ok and any(e.get('engine_mode') == 'DETECTION_ONLY' and e.get('regla_host_numerico') for e in selected)
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
