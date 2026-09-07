"""Browser checks for the standalone prototype using local Chrome's CDP."""
import base64
import csv
import io
import json
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.request
import websocket

ROOT = Path(__file__).resolve().parents[1]
TEMP = Path(tempfile.mkdtemp(prefix='llmap-browser-'))
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
PORT = 9335
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
process = subprocess.Popen([
    CHROME, '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    '--disable-background-networking', '--disable-extensions', '--remote-allow-origins=*',
    f'--remote-debugging-port={PORT}', f'--user-data-dir={TEMP / "profile"}', 'about:blank',
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)

counter = 0
events = []
ws = None

def call(method, params=None):
    global counter
    counter += 1
    req_id = counter
    ws.send(json.dumps(dict(id=req_id, method=method, params=params or {})))
    while True:
        message = json.loads(ws.recv())
        if message.get('id') == req_id:
            if 'error' in message:
                raise RuntimeError(message['error'])
            return message.get('result', {})
        events.append(message)

def js(expression):
    result = call('Runtime.evaluate', dict(expression=expression, returnByValue=True, awaitPromise=True))
    if result.get('exceptionDetails'):
        raise RuntimeError(result['exceptionDetails'])
    return result.get('result', {}).get('value')

def shot(name):
    path = ROOT / 'support' / name
    path.write_bytes(base64.b64decode(call('Page.captureScreenshot', {'format': 'png'})['data']))

def change(id, value):
    js(f"$({json.dumps(id)}).value={json.dumps(value)};$({json.dumps(id)}).dispatchEvent(new Event('change'));true")

try:
    for _ in range(20):
        if process.poll() is not None:
            raise RuntimeError(f'Chrome exited at startup with {process.returncode}')
        try:
            with opener.open(f'http://127.0.0.1:{PORT}/json/list', timeout=1) as response:
                tabs = json.load(response)
            break
        except Exception:
            time.sleep(.1)
    else:
        raise RuntimeError('Chrome did not start')
    page = next(t for t in tabs if t['type'] == 'page' and t['url'] == 'about:blank')
    ws = websocket.create_connection(page['webSocketDebuggerUrl'], timeout=20, suppress_origin=True)
    call('Runtime.enable')
    call('Page.enable')
    call('Network.enable')
    call('Emulation.setDeviceMetricsOverride', {'width': 1440, 'height': 1080, 'deviceScaleFactor': 1, 'mobile': False})
    print('NAV',json.dumps(call('Page.navigate', {'url': (ROOT / 'index.html').as_uri()})),flush=True)
    for _ in range(100):
        if js("document.readyState==='complete' && typeof context!=='undefined'"):
            break
        time.sleep(.1)
    else:
        print(json.dumps(js("({url:location.href,title:document.title,body:document.body?.innerText.slice(0,500),state:document.readyState})"),ensure_ascii=True),flush=True)
        print(json.dumps([e for e in events if e.get('method')=='Runtime.exceptionThrown'],ensure_ascii=True),flush=True)
        raise RuntimeError('Prototype did not initialize')
    time.sleep(.3)
    initial = js("({rows:context.rows.length,active:context.active.length,exact:context.rows.filter(r=>r.exact).length,counts:Object.fromEntries(context.counts),fn:Object.fromEntries(Object.keys(FN).map(k=>[k,context.rows.filter(r=>r.fn===k).length])),photo:!!document.querySelector('.photo-stage img'),bins:context.bins.length,miniBounds:[...document.querySelectorAll('.mini-map circle')].every(c=>Number(c.getAttribute('cy'))>0&&Number(c.getAttribute('cy'))<85),overflow:document.documentElement.scrollWidth>innerWidth})")
    assert initial['rows'] == 1933 and initial['active'] == 1601 and initial['exact'] == 1916, initial
    assert initial['counts']['en'] == 1033 and initial['counts']['ko'] == 86, initial
    assert initial['fn'] == dict(commercial=1149, infrastructure=411, regulatory=321, interpersonal=36, mixed=2, other=14), initial
    assert initial['photo'] and initial['miniBounds'] and not initial['overflow'], initial
    shot('llmap-sample-desktop.png')
    change('language', 'jaOnly')
    assert js('context.active.length') == 779
    change('language', 'ko')
    assert js('context.active.length') == 86
    assert js("[...document.querySelectorAll('.record-card')].every(b=>context.active.some(r=>r.i===Number(b.dataset.record)))")
    js("document.querySelector('[data-mode=count]').click()")
    assert js("Object.fromEntries(Object.keys(COUNT).map(k=>[k,context.rows.filter(r=>countKey(r)===k).length]))") == {'1':1042,'2':719,'3':95,'4':60,'unknown':17}
    js("document.querySelector('[data-mode=function]').click()")
    key = js('context.bins.find(b=>b.rows.length>2).key')
    js(f'selectPoint({json.dumps(key)})')
    assert js('context.listed.length') == js(f'context.bins.find(b=>b.key==={json.dumps(key)}).rows.length')
    js("$('clearPoint').click()")
    assert js('context.listed.length') == 1933
    change('scope', 'all')
    assert js('context.rows.length') == 2029
    change('scope', 'text')
    assert js('context.rows.length') == 1983
    change('roles', 'main')
    main = js("({exact:context.rows.filter(r=>r.exact).length, multi:context.rows.filter(r=>r.exact&&r.currentLangs.length>1).length})")
    assert main['multi'] < 100, main
    change('day', '2026-07-07')
    assert js("context.rows.every(r=>r.date==='2026-07-07')")
    change('function', 'regulatory')
    assert js("context.rows.every(r=>r.fn==='regulatory')")
    js("$('reset').click();$('search').value='no-such-record-987654';$('search').dispatchEvent(new Event('input'))")
    time.sleep(.3)
    empty = js("({rows:context.rows.length,listed:context.listed.length,selected:state.selected,stat:$('statMulti').textContent,next:$('next').disabled,emptyHidden:$('mapEmpty').hidden})")
    assert empty == dict(rows=0,listed=0,selected=None,stat='—',next=True,emptyHidden=False), empty
    js("$('reset').click();document.querySelector('.photo-open').click()")
    assert js("$('photoDialog').open")
    js("$('closePhoto').click()")
    assert not js("$('photoDialog').open")
    call('Browser.setDownloadBehavior', {'behavior':'allow','downloadPath':str(TEMP)})
    change('language', 'ko')
    js("$('exportRows').click()")
    exported = TEMP / 'llmap-filtered-records.csv'
    for _ in range(50):
        if exported.exists():
            break
        time.sleep(.1)
    export_rows = list(csv.DictReader(exported.open(encoding='utf-8-sig',newline='')))
    assert len(export_rows) == 86
    js("$('reset').click()")
    call('Emulation.setDeviceMetricsOverride', {'width':390,'height':844,'deviceScaleFactor':1,'mobile':True})
    js('window.scrollTo(0,0)')
    time.sleep(.2)
    assert not js('document.documentElement.scrollWidth>innerWidth'), js('({width:innerWidth,scroll:document.documentElement.scrollWidth})')
    shot('llmap-sample-mobile.png')
    js("document.querySelector('[data-mode=count]').click()")
    assert js('context.rows.length') == 1933
    errors = [e for e in events if e.get('method') == 'Runtime.exceptionThrown']
    assert not errors, errors
    network = [e['params']['request']['url'] for e in events if e.get('method') == 'Network.requestWillBeSent' and e['params']['request']['url'].startswith(('http:', 'https:'))]
    assert not network, network
    print(json.dumps(dict(result='PASS', initial=initial, exportRows=len(export_rows), mainScope=main,
                          jsErrors=len(errors), externalRequests=len(network), screenshots=['llmap-sample-desktop.png','llmap-sample-mobile.png']),ensure_ascii=True))
finally:
    if ws:
        try:
            call('Browser.close')
        except Exception:
            pass
        ws.close()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.terminate()
