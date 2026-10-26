# -*- coding: utf-8 -*-
"""印刷分层版（UV 分版用）→ $LLMAP_FIGMA_OUT/figprint/ 分块 SVG（默认系统临时目录）

三块画板全部使用地图图层的几何（viewBox 1100x350、等距投影、PAD 55），
印刷宽 290 mm 时画板 = 290 x 92.27 mm（1 unit = 0.2636 mm）。

  a-XXX   试样A 解像度：每种网格粗细一层（5/10/20/40/80/160 m），
          与地图圆点同投影同画板，叠放可对位；格子按数据边界框裁切。
  b-<语言> 试样B 六声部：每种语言一层，x = 地图东西位置 px()（与地图纵向对位），
          另有 b-frame 注记层（西/东）。

每层 = Figma 里一个可单独开关的分组。分块规则同 export_studies_figma.py
（ASCII 实体化、每元素一行、≤17KB）。Run: python export_print_layers.py
"""
from collections import Counter, defaultdict
from pathlib import Path
import json
import os
import tempfile
import math

import build_abstract_studies as B
import export_svg_layers as ex
import export_studies_figma as ef

OUTDIR = Path(os.environ.get('LLMAP_FIGMA_OUT', tempfile.gettempdir())) / 'figprint'
ef.OUTDIR = OUTDIR  # 复用 ef.write_chunks 的分块写出
W, H = ex.W, ex.H
INK = '#273831'
SHORT = {'ja': '日', 'en': '英', 'zh': '中', 'ko': '韩', 'vi': '越', 'ne': '尼'}

# UV 印刷用の CMY 配色（Figma 側で確定した体系をここでも正とする）。
# 一次色=強勢言語（M/C/Y）、二次色=弱勢言語（2 原色の重なり色）。
# 全色重なると黒に収斂する減法混色 —— 透明板の重ね刷りが前提。
CMY_COLORS = {
    'ja': '#e4007f',  # Magenta
    'en': '#00a0e9',  # Cyan
    'zh': '#ffc800',  # Yellow
    'ko': '#7a2e9d',  # C+M 紫
    'vi': '#009944',  # C+Y 緑
    'ne': '#ea5504',  # M+Y 朱
}


def _color(lang: str) -> str:
    return CMY_COLORS.get(lang, B.BY_ID[lang][2])


def study_a_layers(recs, geo):
    px, py, s = geo['px'], geo['py'], geo['s']
    span_x, span_y = geo['span_x'], geo['span_y']
    layers = []
    for gi, g in enumerate((5, 10, 20, 40, 80, 160)):
        bins = defaultdict(Counter)
        for r in recs:
            for lang in r['main']:
                bins[(int(r['x'] // g), int(r['y'] // g))][lang] += 1
        maxn = max(sum(c.values()) for c in bins.values())
        buckets, seen = defaultdict(list), set()
        # 格子は裁切せず**完整に描く**（ユーザー要望）: 数据边界の端の格子が
        # 半块になるのを避ける。境界を数 m 越えるが画板 PAD 内に収まり、
        # 六層の套准（原点・比例尺共有）には影響しない。
        for (bx, by), counter in bins.items():
            lang, _ = counter.most_common(1)[0]
            seen.add(lang)
            total = sum(counter.values())
            op = 0.25 + 0.75 * math.log1p(total) / math.log1p(maxn)
            ob = round(op * 5) / 5
            w = max(0.8, g * s - 0.6)
            hh = max(0.8, g * s - 0.6)
            buckets[(lang, ob)].append(
                ef.rect_sub(px(bx * g) + 0.3, py((by + 1) * g) + 0.3, w, hh))
        els = []
        for (lang, ob), subs in sorted(buckets.items()):
            els += ef.paths(f'fill="{_color(lang)}" fill-opacity="{ob:.2f}"', subs)
        names = ''.join(SHORT.get(l, B.BY_ID[l][1][0])
                        for l in sorted(seen, key=lambda l: list(B.BY_ID).index(l)))
        cx = 55 + gi * 165  # 六层各占一格底注位，叠放时并排成一行图例
        els.append(ef.text_el(cx, 340, 11, INK, f'{g} m', weight='600'))
        els.append(ef.text_el(cx + 38, 340, 9, '#687269', names))
        layers.append((f'a-{g:03d}', f'A{gi + 1} {g}m', els))
    return layers


def study_b_layers(recs, geo):
    """Treatise 版：六声部叠加在同一条中央生命线上，占满整个画板高度。

    Cardew《Treatise》的参照：一条贯穿的中央粗线（生命线）、
    围绕它上下散布的竖划（强弱=长短与离线距离）、页底的空五线谱。
    每种语言一层：主要=长划贴近中线，辅助=中划离线更远，装饰=小圆最远。
    x = 地图东西位置 px()，与画板1/2完全对位。
    """
    px, span_x = geo['px'], geo['span_x']
    CY = 175.0
    order = ['ja', 'en', 'zh', 'ko', 'vi', 'ne']
    layers = []
    for i, lang in enumerate(order):
        _, zh_name, _c = B.BY_ID[lang]
        color = _color(lang)
        els = []
        density = Counter()
        for r in recs:
            if lang in r['main']:
                density[int(r['x'] // 10)] += 1
        if density:
            dmax = max(density.values())
            pts = ' '.join(
                f'{ef.R(px(k * 10 + 5))},{ef.R(CY - 24 - 120 * density.get(k, 0) / dmax)}'
                for k in range(int(span_x // 10) + 1))
            els.append(f'<polyline points="{pts}" fill="none" stroke="{color}" '
                       f'stroke-opacity="0.15" stroke-width="1"/>')
        forte, mezzo, pp = [], [], []
        n = [0, 0, 0]
        for r in recs:
            x = px(r['x'])
            j = B.h01(r['id'], lang) - 0.5
            if lang in r['main']:
                n[0] += 1
                forte.append(ef.rect_sub(x, CY - 44 + j * 56, 2.2, 88))
            elif lang in r['aux']:
                n[1] += 1
                mezzo.append(ef.rect_sub(x, CY - 20 + j * 170, 1.7, 40))
            elif lang in r['decor']:
                n[2] += 1
                pp.append(ef.circle_sub(x, CY + j * 264, 2.0))
        els += ef.paths(f'fill="{color}" fill-opacity="0.5"', forte)
        els += ef.paths(f'fill="{color}" fill-opacity="0.38"', mezzo)
        els += ef.paths(f'fill="none" stroke="{color}" stroke-opacity="0.45" stroke-width="0.8"', pp)
        ly = 18 + i * 15  # 左上角声部名列，随本层开关显隐
        els.append(f'<rect x="8" y="{ly - 8}" width="8" height="8" fill="{color}"/>')
        els.append(ef.text_el(20, ly, 10, INK,
                              f'{zh_name}  f {n[0]} - mp {n[1]} - pp {n[2]}'))
        layers.append((f'b-{lang}', f'B{i + 1} {zh_name}', els))
    # 骨架层：中央生命线 + 底部两组空五线谱（Treatise 页面的固定元素）
    sk = [f'<line x1="40" x2="1060" y1="{CY}" y2="{CY}" stroke="{INK}" stroke-width="2"/>']
    for y0 in (302, 324):
        for k in range(5):
            y = y0 + k * 3.5
            sk.append(f'<line x1="40" x2="1060" y1="{ef.R(y)}" y2="{ef.R(y)}" '
                      f'stroke="{INK}" stroke-opacity="0.5" stroke-width="0.5"/>')
    sk.append(ef.text_el(40, 348, 10, '#687269', '西 ←'))
    sk.append(ef.text_el(1060, 348, 10, '#687269', '→ 东（沿街位置）', anchor='end'))
    layers.append(('b-frame', 'B0 骨架（中线·五线谱）', sk))
    return layers


def main():
    OUTDIR.mkdir(exist_ok=True)
    for old in OUTDIR.glob('*'):
        old.unlink()
    geo = ex.build_geometry(ex.load())  # 全数据 bbox —— 与地图各层完全一致
    recs = B.load()
    for r in recs:  # 覆盖 B.project 的口径：统一到地图几何
        r['x'] = (r['lon'] - geo['min_lon']) * geo['mx']
        r['y'] = (r['lat'] - geo['min_lat']) * geo['my']
    assert len(recs) >= 1900, f'审核口径行数异常: {len(recs)}'
    manifest = []
    for stem, name, els in study_a_layers(recs, geo) + study_b_layers(recs, geo):
        files = ef.write_chunks(stem, els, W, H)
        manifest.append(dict(stem=stem, name=name, w=W, h=H,
                             elements=len(els), chunks=files))
    (OUTDIR / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding='utf-8')
    print(json.dumps(dict(recs=len(recs),
                          layers=[(m['stem'], m['elements'],
                                   [c['bytes'] for c in m['chunks']]) for m in manifest])))


if __name__ == '__main__':
    main()
