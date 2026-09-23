# -*- coding: utf-8 -*-
"""抽象维度可视化试样集 → abstract-studies.html

毕业设计三分法（真实的=地図 / 抽象的=可視化 / 具象的=写真）中
「抽象的」一路的三个维度，各复刻一套用真实数据的试样：

  A 解像度   — Harmon block portraits / Menkman Resolution Studies 谱系。
               同一条街在 5→160 m 网格下重画：分辨率越粗，非日语越先消失。
  B 声の大きさ — Visible Speech / Xenakis / Cardew 图形谱谱系。
               街道位置为时间轴、语言为声部；主要=forte 辅助=mezzo 装饰=pp。
  C 规则与无序 — Nees《Schotter》/ Molnár《(Dés)Ordres》谱系。
               每块标识一个方块，抖动量=数据来源的无序分
               （手作/一过性/重ね書き/贴纸→大，专业印刷/常设→0）。
  C2 载体的泼点 — 9 类担体各画一张同框散点小图（对应用户参考的 3×3 泼点网格）。

口径与 v1 相同：已审核(human-reviewed/final)文字记录、几何逐行同
llmap-sample.template.html。纯静态 SVG，无 JS。Run: python build_abstract_studies.py
"""
from pathlib import Path
from collections import Counter, defaultdict
import csv
import hashlib
import math
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'E:\1_LLmap\data.csv')
OUT = ROOT / 'abstract-studies.html'
W = 1100

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
BY_ID = {v[0]: (k, v[1], v[2]) for k, v in LANGS.items()}
EMPTY = {'', '—', '-', '–', '无', '無'}
INK = '#273831'


def parse_lang(value):
    cleaned = re.sub(r'[（(][^）)]*[）)]', '', value)
    out = []
    for token in re.split(r'[/／,，、;；|]', cleaned):
        token = token.strip()
        if token in EMPTY:
            continue
        token = {'中国語簡体字': '中国語'}.get(token, token)
        if token in LANGS:
            out.append(LANGS[token][0])
    return list(dict.fromkeys(out))


def load():
    rows = list(csv.DictReader(SOURCE.open(encoding='utf-8-sig', newline='')))
    recs = []
    for raw in rows:
        if raw['_status'] not in ('human-reviewed', 'final'):
            continue
        if raw['文字性'] not in ('文字', '含文字'):
            continue
        try:
            lat, lon = float(raw['緯度']), float(raw['経度'])
        except (ValueError, TypeError):
            continue
        recs.append(dict(
            id=raw['SignID'], lat=lat, lon=lon,
            main=parse_lang(raw['主要言語']), aux=parse_lang(raw['補助言語']),
            decor=parse_lang(raw['装飾の言語']),
            quality=raw['製作品質'].strip(), temp=raw['時間性'].strip(),
            over=raw['重ね書き'].strip(), carrier=raw['担体類型'].strip(),
            t=raw['採集日時']))
    return recs


def project(recs):
    min_lon, max_lon = min(r['lon'] for r in recs), max(r['lon'] for r in recs)
    min_lat, max_lat = min(r['lat'] for r in recs), max(r['lat'] for r in recs)
    mid = (min_lat + max_lat) / 2
    mx, my = 111320 * math.cos(math.radians(mid)), 111320
    span_x, span_y = (max_lon - min_lon) * mx, (max_lat - min_lat) * my
    for r in recs:
        r['x'] = (r['lon'] - min_lon) * mx
        r['y'] = (r['lat'] - min_lat) * my
    return span_x, span_y


R = lambda v: round(v, 1)  # noqa: E731


def h01(key, salt=''):
    """SignID → 决定论 [0,1)（复现一致，不用随机种子）。"""
    return int(hashlib.md5((key + salt).encode()).hexdigest()[:8], 16) / 0xFFFFFFFF


# ── A 解像度 ─────────────────────────────────────────────────────────
def study_resolution(recs, span_x, span_y):
    # 六个面板同一比例尺、同一数据边界框（印刷同宽同高）。像素随网格变粗，
    # 超出边界框的格子按边框裁切 —— 与图像像素化的惯例一致。
    panels = []
    s = (W - 20) / span_x
    ph = span_y * s
    for g in (5, 10, 20, 40, 80, 160):
        bins = defaultdict(Counter)
        for r in recs:
            key = (int(r['x'] // g), int(r['y'] // g))
            for lang in r['main']:
                bins[key][lang] += 1
        cells, langs_seen = [], set()
        maxn = max(sum(c.values()) for c in bins.values())
        for (bx, by), counter in bins.items():
            lang, n = counter.most_common(1)[0]
            langs_seen.add(lang)
            total = sum(counter.values())
            op = 0.25 + 0.75 * math.log1p(total) / math.log1p(maxn)
            x0m, x1m = bx * g, min((bx + 1) * g, span_x)
            ym0, ym1 = by * g, min((by + 1) * g, span_y)
            cells.append(
                f'<rect x="{R(10 + x0m * s)}" y="{R(ph - ym1 * s + 2)}" '
                f'width="{R(max(0.8, (x1m - x0m) * s - 0.6))}" '
                f'height="{R(max(0.8, (ym1 - ym0) * s - 0.6))}" '
                f'fill="{BY_ID[lang][2]}" fill-opacity="{op:.2f}"/>')
        cells.append(f'<rect x="10" y="2" width="{W - 20}" height="{R(ph)}" '
                     f'fill="none" stroke="#dcded3" stroke-width="0.8"/>')
        seen = ' · '.join(BY_ID[l][1] for l in
                          sorted(langs_seen, key=lambda l: list(BY_ID).index(l)))
        panels.append(
            f'<div class="res-panel"><svg viewBox="0 0 {W} {R(ph + 4)}">{"".join(cells)}</svg>'
            f'<div class="res-cap"><b>{g} m</b><span>还能看见的主导语言：{seen}</span></div></div>')
    return ('<section><h2>A · 解像度 — 多语言在几米的网格下消失</h2>'
            '<p class="note">同一条街、同一份数据，只改聚合网格。每格取主要语言中最多的一种上色'
            '（面积越深记录越多）。分辨率变粗时，少数语言最先被"平均"掉——这不是街道变了，'
            '是观察的解像度决定了谁可见。谱系：Harmon block portraits · Menkman《Resolution Studies》。</p>'
            + ''.join(panels) + '</section>')


# ── B 声の大きさ ──────────────────────────────────────────────────────
def study_score(recs, span_x, span_y):
    order = ['ja', 'en', 'zh', 'ko', 'vi', 'ne']
    band_h, gap, pad_l = 64, 10, 96
    sw = (W - pad_l - 16) / span_x
    parts, y0 = [], 8
    for lang in order:
        cy = y0 + band_h / 2
        name, zh_name, color = BY_ID[lang]
        # 背景包络：每 10 m 主要声部密度（Visible Speech 的能量带）
        density = Counter()
        for r in recs:
            if lang in r['main']:
                density[int(r['x'] // 10)] += 1
        if density:
            dmax = max(density.values())
            pts = [f'{R(pad_l + (k * 10 + 5) * sw)},{R(cy - (band_h * 0.42) * density.get(k, 0) / dmax)}'
                   for k in range(int(span_x // 10) + 1)]
            parts.append(
                f'<polyline points="{" ".join(pts)}" fill="none" stroke="{color}" '
                f'stroke-opacity="0.18" stroke-width="1"/>')
        parts.append(
            f'<line x1="{pad_l}" x2="{W - 16}" y1="{R(cy)}" y2="{R(cy)}" '
            f'stroke="{INK}" stroke-opacity="0.12" stroke-width="0.7"/>')
        n_main = n_aux = n_dec = 0
        for r in recs:
            x = pad_l + r['x'] * sw
            j = (h01(r['id'], lang) - 0.5)
            if lang in r['main']:
                n_main += 1
                parts.append(f'<rect x="{R(x)}" y="{R(cy - 14 + j * 8)}" width="2.1" height="28" '
                             f'fill="{color}" fill-opacity="0.55"/>')
            elif lang in r['aux']:
                n_aux += 1
                parts.append(f'<rect x="{R(x)}" y="{R(cy - 7 + j * 10)}" width="1.7" height="14" '
                             f'fill="{color}" fill-opacity="0.4"/>')
            elif lang in r['decor']:
                n_dec += 1
                parts.append(f'<circle cx="{R(x)}" cy="{R(cy + j * 20)}" r="2" fill="none" '
                             f'stroke="{color}" stroke-opacity="0.45" stroke-width="0.8"/>')
        parts.append(
            f'<text x="8" y="{R(cy - 6)}" font-size="13" fill="{INK}" font-weight="600">{zh_name}</text>'
            f'<text x="8" y="{R(cy + 10)}" font-size="9" fill="#687269">f {n_main} · mp {n_aux} · pp {n_dec}</text>')
        y0 += band_h + gap
    total_h = y0 + 18
    parts.append(f'<text x="{pad_l}" y="{total_h - 4}" font-size="10" fill="#687269">西 ←</text>'
                 f'<text x="{W - 16}" y="{total_h - 4}" font-size="10" fill="#687269" text-anchor="end">→ 东（沿街位置）</text>')
    return ('<section><h2>B · 声の大きさ — 六声部的街道乐谱</h2>'
            '<p class="note">横轴=沿街位置，每种语言一条声部线。力度来自字段本身的三种角色：'
            '<b>主要语言=forte</b>（长竖线）、<b>辅助=mezzo</b>（短线）、<b>装饰=pianissimo</b>（空心点，'
            '几乎不传递信息、只制造气氛）。背景细线是该声部每 10 m 的密度包络。'
            '注意：这是角色的隐喻力度，不是实际字号或音量。谱系：Visible Speech · Xenakis · Cardew《Treatise》。</p>'
            f'<svg viewBox="0 0 {W} {total_h}">{"".join(parts)}</svg></section>')


# ── C 规则与无序 ──────────────────────────────────────────────────────
def disorder(r):
    s = 0.0
    s += {'手作': 0.40, '半专门': 0.18}.get(r['quality'], 0.0)
    s += {'一过性': 0.28, '临时·季节性': 0.12}.get(r['temp'], 0.0)
    if r['over'].startswith('有'):
        s += 0.22
    if r['carrier'] in ('贴纸', '便签'):
        s += 0.15
    return min(1.0, s)


def study_schotter(recs, span_x):
    col_w, size = 12.0, 7.0
    sw = (W - 32) / span_x
    cols = defaultdict(list)
    for r in sorted(recs, key=lambda r: r['t']):
        cols[int(r['x'] * sw // col_w)].append(r)
    max_stack = max(len(v) for v in cols.values())
    h = int(max_stack * (size + 1.6)) + 46
    parts = []
    for ci, stack in cols.items():
        x0 = 16 + ci * col_w + col_w / 2
        for i, r in enumerate(stack):
            s = disorder(r)
            rot = (h01(r['id'], 'r') - 0.5) * 110 * s
            dx = (h01(r['id'], 'x') - 0.5) * 14 * s
            dy = (h01(r['id'], 'y') - 0.5) * 10 * s
            y = h - 30 - i * (size + 1.6)
            parts.append(
                f'<rect x="{R(x0 - size / 2 + dx)}" y="{R(y + dy)}" width="{size}" height="{size}" '
                f'fill="none" stroke="{INK}" stroke-opacity="{0.5 + 0.3 * s:.2f}" stroke-width="0.9" '
                f'transform="rotate({R(rot)} {R(x0 + dx)} {R(y + size / 2 + dy)})"/>')
    parts.append(f'<text x="16" y="{h - 8}" font-size="10" fill="#687269">西 ←</text>'
                 f'<text x="{W - 16}" y="{h - 8}" font-size="10" fill="#687269" text-anchor="end">→ 东</text>')
    return ('<section><h2>C · 规则与无序 — 街道的 Schotter</h2>'
            '<p class="note">每块标识一个方块，按沿街位置排列、按采集顺序向上堆叠。'
            '方块的偏移与旋转不是随机的美化，而是<b>无序分</b>：手作 +0.40 / 半专门 +0.18 / '
            '一过性 +0.28 / 临时·季节性 +0.12 / 重ね書き有 +0.22 / 贴纸·便签 +0.15；'
            '专业印刷的常设标识稳稳站在格线上。哪一段街在"崩塌"，一眼可见。'
            '谱系：Georg Nees《Schotter》(1968) · Vera Molnár《(Dés)Ordres》。</p>'
            f'<svg viewBox="0 0 {W} {h}">{"".join(parts)}</svg></section>')


def study_splatter(recs, span_x, span_y):
    top = [c for c, _ in Counter(r['carrier'] for r in recs if r['carrier']).most_common(9)]
    pw, ph = 340, 150
    s = min((pw - 20) / (span_x + 5), (ph - 34) / (span_y + 5))
    panels = []
    for carrier in top:
        sub = [r for r in recs if r['carrier'] == carrier]
        bins = Counter((int(r['x'] // 5), int(r['y'] // 5)) for r in sub)
        dots = ''.join(
            f'<circle cx="{R(10 + (bx * 5 + 2.5) * s)}" cy="{R(ph - 28 - (by * 5 + 2.5) * s)}" '
            f'r="{R(math.sqrt(n) * 1.4)}" fill="{INK}" fill-opacity="0.8"/>'
            for (bx, by), n in bins.items())
        panels.append(
            f'<div class="spl"><svg viewBox="0 0 {pw} {ph - 24}">{dots}</svg>'
            f'<div class="spl-cap">{carrier}<span>{len(sub)}</span></div></div>')
    return ('<section><h2>C2 · 九种载体的泼点 — 同一条街，九种存在方式</h2>'
            '<p class="note">同一坐标框，按担体類型拆成九张。贴纸聚在哪里、夹心板站在哪里、'
            '井盖式的"无媒介"文字如何铺满整条街——分布形状本身就是每种载体的性格。</p>'
            '<div class="spl-grid">' + ''.join(panels) + '</div></section>')


def main():
    recs = load()
    assert len(recs) >= 1900, f'审核口径记录数异常: {len(recs)}'
    span_x, span_y = project(recs)
    html = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>抽象的可视化试样 · 新大久保</title>
<style>
body{{margin:0;background:#f5f2eb;color:{INK};font-family:Inter,'Segoe UI','Microsoft YaHei',sans-serif;font-size:14px;line-height:1.7}}
.shell{{max-width:1180px;margin:auto;padding:30px 36px 60px}}
h1{{font-family:Georgia,'Noto Serif SC',serif;font-weight:500;font-size:34px;letter-spacing:2px;margin:0 0 6px}}
.sub{{color:#687269;font-size:12.5px;margin:0 0 8px}}
.triad{{font-size:12px;color:#687269;border-top:1px solid {INK};border-bottom:1px solid #dcded3;padding:10px 0;margin-bottom:26px}}
.triad b{{color:{INK}}}
section{{margin:38px 0;background:#fffdf8;border:1px solid #dcded3;border-radius:6px;padding:22px 26px}}
h2{{font-size:17px;margin:0 0 6px}}
.note{{font-size:12px;color:#687269;margin:0 0 16px;max-width:920px}}
svg{{width:100%;display:block}}
.res-panel{{margin:10px 0}}
.res-cap{{display:flex;gap:14px;font-size:11px;color:#687269;margin-top:2px}}
.res-cap b{{color:{INK};min-width:44px}}
.spl-grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}}
.spl{{border:1px solid #e4e6da;padding:8px;background:#fff}}
.spl-cap{{display:flex;justify-content:space-between;font-size:11.5px;margin-top:4px}}
.spl-cap span{{color:#687269;font-family:Georgia,serif}}
.refs{{font-size:11.5px;color:#687269;border-top:1px solid {INK};padding-top:14px}}
.refs b{{color:{INK}}}
</style></head><body><div class="shell">
<h1>抽象的可视化试样</h1>
<p class="sub">新大久保站西侧 · 已审核文字记录 {len(recs):,} 条 · 三个维度各一套复刻研究 · 与 v1 同一数据同一投影</p>
<div class="triad"><b>真实的</b> = 地图（street atlas v1）&nbsp;&nbsp;/&nbsp;&nbsp;<b>抽象的</b> = 本页三个维度&nbsp;&nbsp;/&nbsp;&nbsp;<b>具象的</b> = 一枚照片（档案栏）</div>
{study_resolution(recs, span_x, span_y)}
{study_score(recs, span_x, span_y)}
{study_schotter(recs, span_x)}
{study_splatter(recs, span_x, span_y)}
<div class="refs"><b>谱系参考</b> —
解像度: L. Harmon &amp; K. Knowlton, Studies in Perception (1966); T. Ruff, jpeg; R. Menkman, Resolution Studies; C. Boltanski.
/ 声の大きさ: Potter/Kopp/Green, Visible Speech (1947); I. Xenakis, Pithoprakta; C. Cardew, Treatise; R. M. Schafer.
/ 规则与无序: G. Nees, Schotter (1968); V. Molnár, (Dés)Ordres; F. Morellet; K. Martin, Chance and Order.<br>
所有图使用相同数据口径与坐标框架；"力度""无序"均为字段的显式映射（映射规则写在各图说明内），不含美学随机。</div>
</div></body></html>"""
    OUT.write_text(html, encoding='utf-8')
    print(f'{OUT} {OUT.stat().st_size:,} bytes, {len(recs)} records')


if __name__ == '__main__':
    main()
