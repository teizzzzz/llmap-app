"""Export the v1 map as aligned vector SVG layers for Illustrator / print.

生成一套**坐标完全对齐**的 SVG 图层文件（Illustrator 直接打开即为可编辑矢量）：
  00-frame.svg      图框：网格、经度范围、指北针、50m 比例尺（唯一含文字的图层）
  01-base-all.svg   底图：当前口径全部记录的灰色圆点
  10-lang-*.svg     语言层：每种语言一个文件（含该语言的记录，circle 面积=记录数）
  20-count.svg      语言数量层（1/2/3/4+/未确定 扇形）
  21-function.svg   标识用途层（扇形）
  30-relation.svg   多语言关系层（单语/复制/重复/部分翻译/互补 扇形）
  90-legend.svg     图例参考页
  combined.svg      以上全部合并为命名分组的单文件（AI 里可整体查看）

几何与统计口径逐行移植 llmap-sample.template.html（等距近似投影、5 m 网格、
r = sqrt(n)*1.95、viewBox 1100x350、固定全数据坐标范围），与网页版数字一致。
默认口径 = 网页版默认视图：已人工审核(human-reviewed/final)的文字记录，
语言计入范围 = 主要+辅助+装饰。

物理尺寸：1 viewBox 单位 = MM_PER_UNIT 毫米（默认 0.5 → 画板 550x175 mm）。
所有文件同一画板尺寸，叠放（亚克力/硫酸纸/AI 图层）时自动对齐。
Run: python export_svg_layers.py   （只读 CSV，不改源文件）
"""
from pathlib import Path
from collections import Counter
import csv
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'E:\1_LLmap\data.csv')
OUT = ROOT / 'svg-layers'
MM_PER_UNIT = 0.5          # 1 viewBox 单位 → 0.5 mm（550x175 mm。AI 内可再缩放）
W, H, PAD = 1100, 350, 55  # 与模板 geometry() 一致
LAYER_LANGS = ['ja', 'en', 'zh', 'ko', 'vi', 'ne']  # 与网页版小地图一致

# ── 与 build_llmap_sample.py 完全一致的分类口径 ─────────────────────
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
FN = {'commercial': ('商业', '#b38a29'), 'infrastructure': ('基础设施', '#387f88'),
      'regulatory': ('规约／行为提醒', '#b84f38'), 'interpersonal': ('交际', '#796aa0'),
      'mixed': ('复合用途', '#bb718b'), 'other': ('其他／待判定', '#92968b')}
COUNT = {'1': ('1 种', '#779486'), '2': ('2 种', '#3e7e86'), '3': ('3 种', '#b58a35'),
         '4': ('4 种及以上', '#b84f38'), 'unknown': ('未确定', '#aaa99c')}
REL = {'单语型': ('单语型', '#8a9b8e'), '复制型': ('复制型', '#3e7e86'),
       '重复型': ('重复型', '#b58a35'), '部分翻译型': ('部分翻译型', '#b84f38'),
       '互补型': ('互补型', '#796aa0'), 'unknown': ('未标注／其他', '#c2c4b8')}
BASE_FILL, BASE_OPACITY, LANG_OPACITY = '#cdd5c7', 0.8, 0.88


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


def relation(value):
    value = value.strip()
    return value if value in REL else 'unknown'


def load():
    rows = list(csv.DictReader(SOURCE.open(encoding='utf-8-sig', newline='')))
    records = []
    for raw in rows:
        langs, unknown = [], []
        for field in ('主要言語', '補助言語', '装飾の言語'):
            known, bad = parse_lang(raw[field])
            langs.extend(known)
            unknown.extend(bad)
        try:
            lat, lon = float(raw['緯度']), float(raw['経度'])
            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                raise ValueError
        except (ValueError, TypeError):
            lat = lon = None
        records.append(dict(
            status=raw['_status'], text=raw['文字性'] in ('文字', '含文字'),
            lat=lat, lon=lon, langs=list(dict.fromkeys(langs)),
            unknown=list(dict.fromkeys(unknown)),
            fn=function(raw['ディスコース類型']), rel=relation(raw['多言語関係'])))
    assert len(records) == 2029, f'CSV 行数变化: {len(records)}（模板口径基于 2029 行，请先复核）'
    return records


# ── 几何：逐行移植模板（固定全数据坐标范围 → 图层可叠放比较） ─────────
def build_geometry(records):
    pts = [r for r in records if r['lat'] is not None]
    min_lon, max_lon = min(r['lon'] for r in pts), max(r['lon'] for r in pts)
    min_lat, max_lat = min(r['lat'] for r in pts), max(r['lat'] for r in pts)
    lat_mid = (min_lat + max_lat) / 2
    mx, my = 111320 * math.cos(math.radians(lat_mid)), 111320
    span_x, span_y = (max_lon - min_lon) * mx, (max_lat - min_lat) * my
    for r in records:
        if r['lat'] is not None:
            r['x'] = (r['lon'] - min_lon) * mx
            r['y'] = (r['lat'] - min_lat) * my
            r['bin'] = (math.floor(r['x'] / 5), math.floor(r['y'] / 5))
        else:
            r['bin'] = None
    s = min((W - 2 * PAD) / (span_x + 10), (H - 95) / (span_y + 10))
    px = lambda x: W / 2 + (x - span_x / 2) * s      # noqa: E731
    py = lambda y: H / 2 + 3 - (y - span_y / 2) * s  # noqa: E731
    # mx/my/min_lat は fetch_basemap.py の逆投影（画板 → 経緯度）にも使う
    return dict(px=px, py=py, s=s, span_x=span_x, span_y=span_y,
                min_lon=min_lon, max_lon=max_lon, min_lat=min_lat,
                max_lat=max_lat, mx=mx, my=my)


def group_bins(rows):
    bins = {}
    for r in rows:
        if r['bin'] is None:
            continue
        bins.setdefault(r['bin'], dict(x=r['bin'][0] * 5 + 2.5, y=r['bin'][1] * 5 + 2.5, rows=[]))
        bins[r['bin']]['rows'].append(r)
    return list(bins.values())


R = lambda n: round(n, 2)  # noqa: E731


def radius(n):
    return math.sqrt(n) * 1.95


def pie(x, y, r, parts):
    total = sum(n for n, _ in parts)
    out, angle = [], -math.pi / 2
    for n, color in parts:
        if not n:
            continue
        if n == total:
            out.append(f'<circle cx="{R(x)}" cy="{R(y)}" r="{R(r)}" fill="{color}"/>')
            break
        nxt = angle + n / total * 2 * math.pi
        large = 1 if nxt - angle > math.pi else 0
        out.append(
            f'<path d="M {R(x)} {R(y)} L {R(x + r * math.cos(angle))} {R(y + r * math.sin(angle))} '
            f'A {R(r)} {R(r)} 0 {large} 1 {R(x + r * math.cos(nxt))} {R(y + r * math.sin(nxt))} Z" '
            f'fill="{color}"/>')
        angle = nxt
    return ''.join(out)


def svg_doc(title, body):
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
            f'width="{W * MM_PER_UNIT}mm" height="{H * MM_PER_UNIT}mm">\n'
            f'<title>{title}</title>\n{body}\n</svg>\n')


def frame_layer(g):
    px, py, s = g['px'], g['py'], g['s']
    parts = []
    x = 0.0
    while x <= g['span_x'] + 5:
        parts.append(f'<line x1="{R(px(x))}" x2="{R(px(x))}" y1="43" y2="303" stroke="#dfe4d8" stroke-width="0.8"/>')
        x += 25
    y = 0.0
    while y <= g['span_y'] + 5:
        parts.append(f'<line x1="40" x2="1060" y1="{R(py(y))}" y2="{R(py(y))}" stroke="#dfe4d8" stroke-width="0.8"/>')
        y += 25
    t = 'font-family="Helvetica, Arial, sans-serif" fill="#687269"'
    parts += [
        f'<text x="35" y="26" font-size="11" {t}>{g["min_lon"]:.4f}&#176; E</text>',
        f'<text x="1065" y="26" text-anchor="end" font-size="11" {t}>{g["max_lon"]:.4f}&#176; E</text>',
        f'<text x="35" y="327" font-size="11" {t}>西</text>',
        f'<text x="1065" y="327" text-anchor="end" font-size="11" {t}>东</text>',
        '<path d="M1036 77 L1036 46 M1032 54 L1036 46 L1040 54" stroke="#4b6555" fill="none"/>',
        f'<text x="1036" y="39" text-anchor="middle" font-size="11" font-family="Helvetica, Arial, sans-serif" fill="#4b6555">N</text>',
        f'<path d="M {R(px(0))} 316 v -5 M {R(px(0))} 313 h {R(s * 50)} M {R(px(50))} 316 v -5" fill="none" stroke="#67796a"/>',
        f'<text x="{R(px(25))}" y="334" text-anchor="middle" font-size="10" {t}>50 m</text>',
    ]
    return '<g id="frame">' + ''.join(parts) + '</g>'


def circles_layer(gid, bins, count_of, fill, opacity):
    parts = []
    for b in bins:
        n = count_of(b['rows'])
        if n:
            parts.append(f'<circle cx="{R(GEO["px"](b["x"]))}" cy="{R(GEO["py"](b["y"]))}" '
                         f'r="{R(radius(n))}" fill="{fill}" fill-opacity="{opacity}"/>')
    return f'<g id="{gid}">' + ''.join(parts) + '</g>'


def pies_layer(gid, bins, key_of, palette):
    parts = []
    for b in bins:
        tally = Counter(key_of(r) for r in b['rows'])
        parts.append(pie(GEO['px'](b['x']), GEO['py'](b['y']), radius(len(b['rows'])),
                         [(tally.get(k, 0), color) for k, (_, color) in palette.items()]))
    return f'<g id="{gid}">' + ''.join(parts) + '</g>'


def count_key(r):
    if r['langs'] and not r['unknown']:
        return str(min(4, len(r['langs'])))
    return 'unknown'


def legend_layer(counts):
    rows, y = [], 30
    t = 'font-family="Helvetica, Arial, sans-serif" font-size="11" fill="#273831"'

    def section(title, items):
        nonlocal y
        rows.append(f'<text x="40" y="{y}" font-weight="bold" {t}>{title}</text>')
        y += 18
        for label, color in items:
            rows.append(f'<circle cx="46" cy="{y - 4}" r="4.5" fill="{color}"/>'
                        f'<text x="58" y="{y}" {t}>{label}</text>')
            y += 16
        y += 10

    section('语言层（含该语言的记录）',
            [(f'{LANGS_BY_ID[k][1]}（{counts.get(k, 0)} 条）', LANGS_BY_ID[k][2]) for k in LAYER_LANGS])
    section('底图', [('当前口径全部记录（5 m 网格，圆面积=记录数）', BASE_FILL)])
    section('语言数量', [(v[0], v[1]) for v in COUNT.values()])
    section('标识用途', [(v[0], v[1]) for v in FN.values()])
    section('多语言关系', [(v[0], v[1]) for v in REL.values()])
    return '<g id="legend">' + ''.join(rows) + '</g>'


LANGS_BY_ID = {v[0]: (k, v[1], v[2]) for k, v in LANGS.items()}


def main():
    records = load()
    global GEO
    GEO = build_geometry(records)
    scope = [r for r in records if r['status'] in ('human-reviewed', 'final') and r['text']]
    assert len(scope) == 1933, f'审核口径行数变化: {len(scope)}'
    bins = group_bins(scope)
    counts = Counter(lang for r in scope for lang in r['langs'])
    assert counts['ja'] == 1601 and counts['en'] == 1033, '语言计数与模板控制总数不一致'

    OUT.mkdir(exist_ok=True)
    files = {}
    files['00-frame.svg'] = frame_layer(GEO)
    files['01-base-all.svg'] = circles_layer('base-all', bins, len, BASE_FILL, BASE_OPACITY)
    for lang in LAYER_LANGS:
        name, _, color = LANGS_BY_ID[lang]
        files[f'10-lang-{lang}.svg'] = circles_layer(
            f'lang-{lang}', bins,
            lambda rows, k=lang: sum(1 for r in rows if k in r['langs']), color, LANG_OPACITY)
    files['20-count.svg'] = pies_layer('count', bins, count_key, COUNT)
    files['21-function.svg'] = pies_layer('function', bins, lambda r: r['fn'], FN)
    files['30-relation.svg'] = pies_layer('relation', bins, lambda r: r['rel'], REL)
    files['90-legend.svg'] = legend_layer(counts)

    titles = {'00-frame.svg': '图框 · 网格/指北/比例尺', '01-base-all.svg': '底图 · 全部记录',
              '20-count.svg': '语言数量', '21-function.svg': '标识用途',
              '30-relation.svg': '多语言关系', '90-legend.svg': '图例'}
    for fname, body in files.items():
        title = titles.get(fname) or f'语言层 · {LANGS_BY_ID[fname[8:10]][1]}'
        (OUT / fname).write_text(svg_doc(f'LLMap 新大久保 · {title} · 1933 条已审核文字记录', body),
                                 encoding='utf-8')
    combined = '\n'.join(files[k] for k in files if k != '90-legend.svg')
    (OUT / 'combined.svg').write_text(
        svg_doc('LLMap 新大久保 · 全图层合并（命名分组）', combined), encoding='utf-8')
    print(json.dumps(dict(out=str(OUT), files=len(files) + 1, scope=len(scope),
                          bins=len(bins), artboard_mm=[W * MM_PER_UNIT, H * MM_PER_UNIT]),
                     ensure_ascii=False))


if __name__ == '__main__':
    main()
