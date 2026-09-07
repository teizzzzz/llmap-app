"""Build an offline HTML exploration from the user's CSV; never modify sources."""
from pathlib import Path
from collections import Counter
import base64
import csv
import hashlib
import io
import json
import re
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'E:\1_LLmap\data.csv')
LANGS = {
    '日本語': ('ja', '日语', '#b84f38'), '英語': ('en', '英语', '#387f88'),
    '中国語': ('zh', '中文', '#b38a29'), '韓国語': ('ko', '韩语', '#796aa0'),
    'ベトナム語': ('vi', '越南语', '#5b8870'), 'ネパール語': ('ne', '尼泊尔语', '#bb718b'),
    'タイ語': ('th', '泰语', '#77853d'), 'ヒンディー語': ('hi', '印地语', '#986346'),
    'アラビア語': ('ar', '阿拉伯语', '#446392'), 'スペイン語': ('es', '西班牙语', '#96776e'),
    'ミャンマー語': ('my', '缅甸语', '#797336'), 'フランス語': ('fr', '法语', '#6275a3'),
    'インドネシア語': ('id', '印度尼西亚语', '#427e74'), 'ポーランド語': ('pl', '波兰语', '#a86d70'),
    'ロシア語': ('ru', '俄语', '#89608e'), 'ウルドゥー語': ('ur', '乌尔都语', '#769171'),
    'サンスクリット語': ('sa', '梵语', '#867d60'),
}
EMPTY = {'', '—', '-', '–', '无', '無'}

def parse_lang(value):
    cleaned = re.sub(r'[（(][^）)]*[）)]', '', value)
    known, unknown = [], []
    for token in re.split(r'[/／,，、;；|]', cleaned):
        token = token.strip()
        if token in EMPTY:
            continue
        token = {'中国語簡体字': '中国語'}.get(token, token)
        if token in LANGS:
            known.append(LANGS[token][0])
        else:
            unknown.append(token)
    return list(dict.fromkeys(known)), list(dict.fromkeys(unknown))

def function(value):
    value = value.translate(str.maketrans('商業話語規約基礎設施際', '商业话语规约基础设施际'))
    matches = [key for word, key in [('商业', 'commercial'), ('基础设施', 'infrastructure'),
                                    ('规约', 'regulatory'), ('交际', 'interpersonal')] if word in value]
    return matches[0] if len(matches) == 1 else ('mixed' if len(matches) > 1 else 'other')

def main():
    rows = list(csv.DictReader(SOURCE.open(encoding='utf-8-sig', newline='')))
    headers = list(rows[0])
    records = []
    photo_index = {}
    for path in sorted(SOURCE.parent.rglob('*.jpg')):
        photo_index.setdefault(path.name, path)
    images = {}
    for n, raw in enumerate(rows):
        roles, uncertain = {}, []
        for field, key in [('主要言語', 'main'), ('補助言語', 'aux'), ('装飾の言語', 'decor')]:
            roles[key], bad = parse_lang(raw[field])
            uncertain.extend(bad)
        known = list(dict.fromkeys(sum(roles.values(), [])))
        try:
            lat, lon = float(raw['緯度']), float(raw['経度'])
            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                raise ValueError('coordinate range')
        except (ValueError, TypeError):
            lat = lon = None
        record = dict(i=n, id=raw['SignID'], label=raw['DisplayID'] or raw['SignID'],
                      status=raw['_status'], text=raw['文字性'] in ('文字', '含文字'),
                      lat=lat, lon=lon, date=raw['採集日時'][:10], roles=roles,
                      unknown=list(dict.fromkeys(uncertain)), langs=known,
                      fn=function(raw['ディスコース類型']), raw=[raw[h] for h in headers])
        name = raw['写真ファイル名']
        if name in photo_index:
            if name not in images:
                with Image.open(photo_index[name]) as original:
                    thumb = ImageOps.exif_transpose(original).convert('RGB')
                    thumb.thumbnail((480, 420))
                    buffer = io.BytesIO()
                    thumb.save(buffer, format='JPEG', quality=69, optimize=True)
                    images[name] = 'data:image/jpeg;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')
            record['image'] = name
        records.append(record)
    reviewed = [r for r in records if r['status'] in ('human-reviewed', 'final') and r['text']]
    counts = Counter(lang for r in reviewed for lang in r['langs'])
    exact = [r for r in reviewed if r['langs'] and not r['unknown']]
    assert len({r['id'] for r in records}) == len(records), 'Duplicate SignID needs explicit resolution'
    # Independently established control totals from the source CSV.
    assert len(records) == 2029 and len(reviewed) == 1933
    assert counts['ja'] == 1601 and counts['en'] == 1033 and len(exact) == 1916
    payload = dict(meta=dict(source='data.csv', sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                            total=len(records), reviewedText=len(reviewed), exact=len(exact),
                            photos=sum('image' in r for r in records)),
                   languages=[dict(id=v[0], name=v[1], color=v[2], source=k) for k, v in LANGS.items()],
                   headers=headers, records=records, images=images)
    serialized = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')
    template = (ROOT / 'support' / 'llmap-sample.template.html').read_text(encoding='utf-8')
    output = ROOT / 'index.html'
    output.write_text(template.replace('__EMBEDDED_DATA__', serialized), encoding='utf-8')
    print(json.dumps(dict(file=str(output), bytes=output.stat().st_size, total=len(records),
                         reviewedText=len(reviewed), exact=len(exact), presence=counts,
                         photoMatches=payload['meta']['photos']), ensure_ascii=True))

if __name__ == '__main__':
    main()
