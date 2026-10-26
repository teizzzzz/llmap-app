# -*- coding: utf-8 -*-
"""抽象试样 → Figma 导入用分块 SVG（merged-path 版）

与 build_abstract_studies.py 同数据、同映射、同布局，但把同样式的标记
合并为少量大 <path>（Figma 里一个样式桶=一个矢量节点，可整体改色、不卡文件）。
输出: $LLMAP_FIGMA_OUT/figstudies/（默认系统临时目录）下的分块文件（ASCII 实体化、每元素一行、≤17KB）
以及 manifest.json（框名/尺寸/块清单）。Run: python export_studies_figma.py
"""
from pathlib import Path
from collections import Counter, defaultdict
import json
import os
import tempfile
import math

import build_abstract_studies as B

OUTDIR = Path(os.environ.get('LLMAP_FIGMA_OUT', tempfile.gettempdir())) / 'figstudies'
W = 1100
INK = '#273831'
R = lambda v: round(v, 1)  # noqa: E731
MAX_D = 13000   # 单个 path 的 d 上限
CHUNK = 17000   # 单块文件上限


def paths(attr, subpaths):
    """subpath 列表 → 若干 <path>（按 MAX_D 切分）。attr 不含 d。"""
    out, cur = [], ''
    for s in subpaths:
        if cur and len(cur) + len(s) > MAX_D:
            out.append(f'<path d="{cur}" {attr}/>')
            cur = ''
        cur += s
    if cur:
        out.append(f'<path d="{cur}" {attr}/>')
    return out


def rect_sub(x, y, w, h):
    return f'M{R(x)} {R(y)}h{R(w)}v{R(h)}h{R(-w)}Z'


def circle_sub(cx, cy, r):
    return (f'M{R(cx - r)} {R(cy)}a{R(r)} {R(r)} 0 1 0 {R(2 * r)} 0'
            f'a{R(r)} {R(r)} 0 1 0 {R(-2 * r)} 0Z')


def quad_sub(cx, cy, size, rot_deg, dx, dy):
    a = math.radians(rot_deg)
    c, s = math.cos(a), math.sin(a)
    half = size / 2
    pts = []
    for px, py in ((-half, -half), (half, -half), (half, half), (-half, half)):
        pts.append((cx + dx + px * c - py * s, cy + dy + px * s + py * c))
    return ('M' + 'L'.join(f'{R(x)} {R(y)}' for x, y in pts) + 'Z')


def text_el(x, y, size, fill, s, anchor='', weight=''):
    extra = (f' text-anchor="{anchor}"' if anchor else '') + \
            (f' font-weight="{weight}"' if weight else '')
    s = s.encode('ascii', 'xmlcharrefreplace').decode()
    return (f'<text x="{R(x)}" y="{R(y)}" font-size="{size}" '
            f'font-family="Helvetica, Arial, sans-serif" fill="{fill}"{extra}>{s}</text>')


# ── A 解像度 ─────────────────────────────────────────────────────────
# 六个面板**同一比例尺、同一数据边界框**（印刷时同宽同高可叠放）。
# 像素随网格变粗，超出边界框的格子按边框裁切 —— 与图像像素化的惯例一致。
def study_a(recs, span_x, span_y):
    sc = (W - 20) / span_x
    ph = span_y * sc
    els, y0 = [], 0
    for g in (5, 10, 20, 40, 80, 160):
        bins = defaultdict(Counter)
        for r in recs:
            for lang in r['main']:
                bins[(int(r['x'] // g), int(r['y'] // g))][lang] += 1
        maxn = max(sum(c.values()) for c in bins.values())
        buckets, langs_seen = defaultdict(list), set()
        for (bx, by), counter in bins.items():
            lang, _ = counter.most_common(1)[0]
            langs_seen.add(lang)
            total = sum(counter.values())
            op = 0.25 + 0.75 * math.log1p(total) / math.log1p(maxn)
            ob = round(op * 5) / 5
            # 裁切到共同边界框
            x0m, x1m = bx * g, min((bx + 1) * g, span_x)
            ym0, ym1 = by * g, min((by + 1) * g, span_y)
            w = max(0.8, (x1m - x0m) * sc - 0.6)
            hh = max(0.8, (ym1 - ym0) * sc - 0.6)
            buckets[(lang, ob)].append(
                rect_sub(10 + x0m * sc, y0 + ph - ym1 * sc, w, hh))
        for (lang, ob), subs in sorted(buckets.items()):
            els += paths(f'fill="{B.BY_ID[lang][2]}" fill-opacity="{ob:.2f}"', subs)
        els.append(f'<rect x="10" y="{R(y0)}" width="{W - 20}" height="{R(ph)}" '
                   f'fill="none" stroke="#dcded3" stroke-width="0.8"/>')
        seen = ' / '.join(B.BY_ID[l][1] for l in sorted(langs_seen, key=lambda l: list(B.BY_ID).index(l)))
        els.append(text_el(10, y0 + ph + 14, 12, INK, f'{g} m', weight='600'))
        els.append(text_el(70, y0 + ph + 14, 10, '#687269', f'还能看见的主导语言: {seen}'))
        y0 += ph + 30
    return els, y0


# ── B 声の大きさ ──────────────────────────────────────────────────────
def study_b(recs, span_x):
    order = ['ja', 'en', 'zh', 'ko', 'vi', 'ne']
    band_h, gap, pad_l = 64, 10, 96
    sw = (W - pad_l - 16) / span_x
    els, y0 = [], 8
    for lang in order:
        cy = y0 + band_h / 2
        _, zh_name, color = B.BY_ID[lang]
        density = Counter()
        for r in recs:
            if lang in r['main']:
                density[int(r['x'] // 10)] += 1
        if density:
            dmax = max(density.values())
            pts = ' '.join(
                f'{R(pad_l + (k * 10 + 5) * sw)},{R(cy - band_h * 0.42 * density.get(k, 0) / dmax)}'
                for k in range(int(span_x // 10) + 1))
            els.append(f'<polyline points="{pts}" fill="none" stroke="{color}" '
                       f'stroke-opacity="0.18" stroke-width="1"/>')
        els.append(f'<line x1="{pad_l}" x2="{W - 16}" y1="{R(cy)}" y2="{R(cy)}" '
                   f'stroke="{INK}" stroke-opacity="0.12" stroke-width="0.7"/>')
        forte, mezzo, pp = [], [], []
        n = [0, 0, 0]
        for r in recs:
            x = pad_l + r['x'] * sw
            j = B.h01(r['id'], lang) - 0.5
            if lang in r['main']:
                n[0] += 1
                forte.append(rect_sub(x, cy - 14 + j * 8, 2.1, 28))
            elif lang in r['aux']:
                n[1] += 1
                mezzo.append(rect_sub(x, cy - 7 + j * 10, 1.7, 14))
            elif lang in r['decor']:
                n[2] += 1
                pp.append(circle_sub(x, cy + j * 20, 2))
        els += paths(f'fill="{color}" fill-opacity="0.55"', forte)
        els += paths(f'fill="{color}" fill-opacity="0.4"', mezzo)
        els += paths(f'fill="none" stroke="{color}" stroke-opacity="0.45" stroke-width="0.8"', pp)
        els.append(text_el(8, cy - 6, 13, INK, zh_name, weight='600'))
        els.append(text_el(8, cy + 10, 9, '#687269', f'f {n[0]} - mp {n[1]} - pp {n[2]}'))
        y0 += band_h + gap
    h = y0 + 18
    els.append(text_el(pad_l, h - 4, 10, '#687269', '西 ←'))
    els.append(text_el(W - 16, h - 4, 10, '#687269', '→ 东（沿街位置）', anchor='end'))
    return els, h


# ── C 规则与无序 ──────────────────────────────────────────────────────
def study_c(recs, span_x):
    col_w, size = 12.0, 7.0
    sw = (W - 32) / span_x
    cols = defaultdict(list)
    for r in sorted(recs, key=lambda r: r['t']):
        cols[int(r['x'] * sw // col_w)].append(r)
    h = int(max(len(v) for v in cols.values()) * (size + 1.6)) + 46
    buckets = defaultdict(list)
    for ci, stack in cols.items():
        x0 = 16 + ci * col_w + col_w / 2
        for i, r in enumerate(stack):
            s = B.disorder(r)
            rot = (B.h01(r['id'], 'r') - 0.5) * 110 * s
            dx = (B.h01(r['id'], 'x') - 0.5) * 14 * s
            dy = (B.h01(r['id'], 'y') - 0.5) * 10 * s
            y = h - 30 - i * (size + 1.6) + size / 2
            ob = round((0.5 + 0.3 * s) * 10) / 10
            buckets[ob].append(quad_sub(x0, y, size, rot, dx, dy))
    els = []
    for ob, subs in sorted(buckets.items()):
        els += paths(f'fill="none" stroke="{INK}" stroke-opacity="{ob:.2f}" stroke-width="0.9"', subs)
    els.append(text_el(16, h - 8, 10, '#687269', '西 ←'))
    els.append(text_el(W - 16, h - 8, 10, '#687269', '→ 东', anchor='end'))
    return els, h


# ── C2 载体泼点 ───────────────────────────────────────────────────────
def study_c2(recs, span_x, span_y):
    top = [c for c, _ in Counter(r['carrier'] for r in recs if r['carrier']).most_common(9)]
    pw, ph, gx, gy = 352, 148, 22, 34
    sc = min((pw - 20) / (span_x + 5), (ph - 30) / (span_y + 5))
    els = []
    for i, carrier in enumerate(top):
        ox, oy = (i % 3) * (pw + gx), (i // 3) * (ph + gy)
        sub = [r for r in recs if r['carrier'] == carrier]
        bins = Counter((int(r['x'] // 5), int(r['y'] // 5)) for r in sub)
        subs = [circle_sub(ox + 10 + (bx * 5 + 2.5) * sc, oy + ph - 24 - (by * 5 + 2.5) * sc,
                           math.sqrt(n) * 1.4) for (bx, by), n in bins.items()]
        els += paths(f'fill="{INK}" fill-opacity="0.8"', subs)
        els.append(f'<rect x="{ox}" y="{oy}" width="{pw}" height="{ph - 18}" fill="none" '
                   f'stroke="#e4e6da" stroke-width="1"/>')
        els.append(text_el(ox + 2, oy + ph + 8, 11, INK, carrier))
        els.append(text_el(ox + pw - 2, oy + ph + 8, 11, '#687269', str(len(sub)), anchor='end'))
    h = 3 * (ph + gy) + 4
    return els, h


def write_chunks(stem, els, w, h):
    files, cur, idx = [], [], 0
    cur_len = 0
    for e in els:
        if cur and cur_len + len(e) > CHUNK:
            f = OUTDIR / f'{stem}.{idx}.svg'
            f.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}">\n'
                         + '\n'.join(cur) + '\n</svg>', encoding='ascii')
            files.append(dict(file=f.name, bytes=f.stat().st_size))
            cur, cur_len, idx = [], 0, idx + 1
        cur.append(e)
        cur_len += len(e) + 1
    if cur:
        f = OUTDIR / f'{stem}.{idx}.svg'
        f.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}">\n'
                     + '\n'.join(cur) + '\n</svg>', encoding='ascii')
        files.append(dict(file=f.name, bytes=f.stat().st_size))
    return files


def main():
    OUTDIR.mkdir(exist_ok=True)
    for old in OUTDIR.glob('*'):
        old.unlink()
    recs = B.load()
    span_x, span_y = B.project(recs)
    manifest = []
    for stem, name, fn in (
            ('study-a', '试样A · 解像度（5→160m）', lambda: study_a(recs, span_x, span_y)),
            ('study-b', '试样B · 声の大きさ（六声部乐谱）', lambda: study_b(recs, span_x)),
            ('study-c', '试样C · 规则与无序（Schotter）', lambda: study_c(recs, span_x)),
            ('study-c2', '试样C2 · 九种载体的泼点', lambda: study_c2(recs, span_x, span_y))):
        els, h = fn()
        files = write_chunks(stem, els, W, int(h))
        manifest.append(dict(stem=stem, name=name, w=W, h=int(h),
                             elements=len(els), chunks=files))
    (OUTDIR / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding='utf-8')
    print(json.dumps([(m['stem'], m['h'], m['elements'],
                       [c['bytes'] for c in m['chunks']]) for m in manifest]))


if __name__ == '__main__':
    main()
