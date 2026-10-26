"""印刷3 追加声部：「その他」（六种以外的全部语言合为第七声部）。

规则与 export_print_layers.study_b_layers 完全一致（中央生命线 y=175，
f=长划 / mp=中划 / pp=小圆，抖动 = SignID 确定性哈希，10 m 密度包络）。
计入口径与印刷1「16 その他」层一致：六种以外的已知语言，
以及标为「インド言語」「その他」的记录；「不明」「判読不能」不计。
输出 svg-layers/b-other.svg（单文件，1100×350）。只读 CSV。
Run: python export_other_voice_layer.py [data.csv 路径]
"""
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

import build_abstract_studies as B
import export_svg_layers as ex
import export_studies_figma as ef

SIX = {'ja', 'en', 'zh', 'ko', 'vi', 'ne'}
EXTRA = {'インド言語', 'その他'}
COLOR = '#8c8c8c'   # 中性灰（K 约 55%）：CMY 全部叠色趋向的黑，取其淡版
INK = '#273831'
CY = 175.0


def other_tokens(value):
    """返回该字段是否含「六种以外」的语言。"""
    cleaned = re.sub(r'[（(][^）)]*[）)]', '', value or '')
    for t in re.split(r'[/／,，、;；|]', cleaned):
        t = t.strip()
        t = {'中国語簡体字': '中国語'}.get(t, t)
        if t in EXTRA:
            return True
        if t in B.LANGS and B.LANGS[t][0] not in SIX:
            return True
    return False


def main():
    if len(sys.argv) > 1:
        ex.SOURCE = B.SOURCE = Path(sys.argv[1])
    geo = ex.build_geometry(ex.load())
    recs = B.load()
    raw = {r['SignID']: r for r in csv.DictReader(B.SOURCE.open(encoding='utf-8-sig', newline=''))}
    px = geo['px']
    density, forte, mezzo, pp, n = Counter(), [], [], [], [0, 0, 0]
    for r in recs:
        r['x'] = (r['lon'] - geo['min_lon']) * geo['mx']
        row = raw[r['id']]
        x = px(r['x'])
        j = B.h01(r['id'], 'other') - 0.5
        if other_tokens(row['主要言語']):
            n[0] += 1
            density[int(r['x'] // 10)] += 1
            forte.append(ef.rect_sub(x, CY - 44 + j * 56, 2.2, 88))
        elif other_tokens(row['補助言語']):
            n[1] += 1
            mezzo.append(ef.rect_sub(x, CY - 20 + j * 170, 1.7, 40))
        elif other_tokens(row['装飾の言語']):
            n[2] += 1
            pp.append(ef.circle_sub(x, CY + j * 264, 2.0))
    els = []
    if density:
        dmax = max(density.values())
        pts = ' '.join(f'{ef.R(px(k * 10 + 5))},{ef.R(CY - 24 - 120 * density.get(k, 0) / dmax)}'
                       for k in range(int(geo['span_x'] // 10) + 1))
        els.append(f'<polyline points="{pts}" fill="none" stroke="{COLOR}" stroke-opacity="0.15" stroke-width="1"/>')
    els += ef.paths(f'fill="{COLOR}" fill-opacity="0.5"', forte)
    els += ef.paths(f'fill="{COLOR}" fill-opacity="0.38"', mezzo)
    els += ef.paths(f'fill="none" stroke="{COLOR}" stroke-opacity="0.45" stroke-width="0.8"', pp)
    els.append(f'<rect x="8" y="10" width="8" height="8" fill="{COLOR}"/>')
    label = f'その他 f {n[0]} - mp {n[1]} - pp {n[2]}'
    els.append(ef.text_el(20, 18, 10, INK, label))
    out = ex.OUT / 'b-other.svg'
    out.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {ex.W} {ex.H}">\n'
                   + '\n'.join(els) + '\n</svg>\n', encoding='utf-8')
    print(json.dumps(dict(out=str(out), f=n[0], mp=n[1], pp=n[2], total=sum(n), bytes=out.stat().st_size), ensure_ascii=False))


if __name__ == '__main__':
    main()
