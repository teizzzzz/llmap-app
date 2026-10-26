"""印刷1 追加层：「その他」语言层（六种主要语言以外的全部语言合为一层）。

复用 export_svg_layers.py 的读取/几何/圆点口径（5 m 网格，r = sqrt(n)*1.95），
只额外输出 svg-layers/10-lang-other.svg，不重写其它图层文件。
计入：已审核文字记录中，含 LAYER_LANGS（日英中韩越尼）以外任一已知语言，
或标为「インド言語」「その他」的记录。「不明」「判読不能」不计入。
Run: python export_other_lang_layer.py [data.csv 路径]   （只读 CSV）
"""
import json
import sys
from collections import Counter
from pathlib import Path

import export_svg_layers as E

EXTRA_TOKENS = {'インド言語', 'その他'}
COLOR = '#92968b'


def is_other(r):
    return any(l not in E.LAYER_LANGS for l in r['langs']) or any(t in EXTRA_TOKENS for t in r['unknown'])


def main():
    if len(sys.argv) > 1:
        E.SOURCE = Path(sys.argv[1])
    records = E.load()
    E.GEO = E.build_geometry(records)
    scope = [r for r in records if r['status'] in ('human-reviewed', 'final') and r['text']]
    assert len(scope) == 1933, f'审核口径行数变化: {len(scope)}'
    bins = E.group_bins(scope)
    others = [r for r in scope if is_other(r)]
    body = E.circles_layer('lang-other', bins, lambda rows: sum(1 for r in rows if is_other(r)),
                           COLOR, E.LANG_OPACITY)
    E.OUT.mkdir(exist_ok=True)
    out = E.OUT / '10-lang-other.svg'
    out.write_text(E.svg_doc(f'LLMap 新大久保 · 语言层 · 其他语言 · {len(others)} 条', body), encoding='utf-8')
    detail = Counter(l for r in others for l in r['langs'] if l not in E.LAYER_LANGS)
    detail.update(t for r in others for t in r['unknown'] if t in EXTRA_TOKENS)
    print(json.dumps(dict(out=str(out), records=len(others), circles=body.count('<circle'),
                          detail=dict(detail.most_common())), ensure_ascii=False))


if __name__ == '__main__':
    main()
