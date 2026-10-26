# -*- coding: utf-8 -*-
"""LLMap 查阅用軽量 Web（Lingscape 参照）のビルド。

生成物（このフォルダが成果物。zip で人に渡せる / index.html 双击で動く）:
  index.html   アプリ本体（テンプレート web-viewer.template.html をそのまま複製）
  data.js      window.LLMAP_DATA = 審核済み 1933 記録（座標は印刷板と同一投影）
  basemap.js   window.LLMAP_BASEMAP = 自前描画の OSM 底図 SVG（タイル不要・完全オフライン）
  thumbs/      裁剪写真の縮略図（長辺 360px JPEG。原図は含めない = 軽量）

データ口径・投影は visualization-sample と同一（export_svg_layers.py を再利用）。
Run: python build_web_viewer.py   （源 CSV・原写真は読むだけで変更しない）
"""
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
SUPPORT = HERE.parent / 'visualization-sample' / 'support'
sys.path.insert(0, str(SUPPORT))

import export_svg_layers as ex  # noqa: E402  (幾何・口径の単一ソース)

SOURCE_DIR = Path(r'E:\1_LLmap')
THUMB_EDGE = 360
THUMB_QUALITY = 72

# 表示用フィールド（CSV 正準キー。値は正準値のまま表示する）
DETAIL_FIELDS = [
    '名称', '文字性', '主要言語', '補助言語', '装飾の言語', '文字体系',
    '多言語関係', '担体類型', '放置位置', '時間性', '可読性', '重ね書き',
    '設置主体', 'ディスコース類型', '製作品質', '備考', '採集日時',
]


def build_thumbs(records, photo_index):
    out = HERE / 'thumbs'
    out.mkdir(exist_ok=True)
    made = reused = missing = 0
    for r in records:
        name = r['raw'].get('写真ファイル名', '')
        if not name or name not in photo_index:
            r['ph'] = None
            missing += 1
            continue
        src = photo_index[name]
        dst = out / name
        if dst.is_file() and dst.stat().st_mtime >= src.stat().st_mtime:
            reused += 1
        else:
            try:
                with Image.open(src) as im:
                    im = ImageOps.exif_transpose(im).convert('RGB')
                    im.thumbnail((THUMB_EDGE, THUMB_EDGE))
                    buf = io.BytesIO()
                    im.save(buf, format='JPEG', quality=THUMB_QUALITY,
                            optimize=True)
                dst.write_bytes(buf.getvalue())
                made += 1
            except OSError:
                r['ph'] = None
                missing += 1
                continue
        r['ph'] = name
    return made, reused, missing


def main():
    import csv
    rows = list(csv.DictReader(
        (SOURCE_DIR / 'data.csv').open(encoding='utf-8-sig', newline='')))

    # 幾何は印刷板と完全同一（全 2029 条の bbox）
    ex_records = ex.load()
    geo = ex.build_geometry(ex_records)

    # 審核済み・文字記録のみ（1933 条）。ex.load と同順なので zip で対応付ける。
    records = []
    for raw, parsed in zip(rows, ex_records):
        if parsed['status'] not in ('human-reviewed', 'final') or not parsed['text']:
            continue
        rec = {
            'id': raw['SignID'],
            'd': raw.get('DisplayID') or raw['SignID'],
            'main': ex.parse_lang(raw['主要言語'])[0],
            'aux': ex.parse_lang(raw['補助言語'])[0],
            'decor': ex.parse_lang(raw['装飾の言語'])[0],
            'raw': {k: raw.get(k, '') for k in DETAIL_FIELDS + ['写真ファイル名']},
        }
        if parsed['lat'] is not None:
            rec['x'] = round(geo['px'](parsed['x']), 1)
            rec['y'] = round(geo['py'](parsed['y']), 1)
            rec['lat'] = parsed['lat']
            rec['lon'] = parsed['lon']
        records.append(rec)

    photo_index = {}
    for p in sorted(SOURCE_DIR.rglob('*.jpg')):
        photo_index.setdefault(p.name, p)
    # 桌面版（Research Console）のデータ目录を第二の写真源にする
    # （導入済みの全裁剪写真がここに揃っている）。
    import os
    roaming = Path(os.environ.get('APPDATA', '')) / 'llmap' / 'photos'
    if roaming.is_dir():
        for p in sorted(roaming.glob('*.jpg')):
            photo_index.setdefault(p.name, p)
    made, reused, missing = build_thumbs(records, photo_index)

    # data.js（写真ファイル名は raw から除去 — ph に一本化）
    for r in records:
        r['raw'].pop('写真ファイル名', None)
    langs_meta = {k: {'name': v[0], 'color': v[2]}
                  for k, v in ex.LANGS_BY_ID.items()}
    # 画板（1100x350）四隅の経緯度 —— 自前底図を Leaflet の svgOverlay として
    # 正確に貼るための境界（余白なし。fetch_basemap の逆投影と同式）。
    def inv(u, v):
        x = (u - ex.W / 2) / geo['s'] + geo['span_x'] / 2
        y = (ex.H / 2 + 3 - v) / geo['s'] + geo['span_y'] / 2
        return (geo['min_lat'] + y / geo['my'], geo['min_lon'] + x / geo['mx'])
    south_west = inv(0, ex.H)
    north_east = inv(ex.W, 0)

    payload = {
        'records': records,
        'meta': {
            'total': len(records),
            'withGps': sum(1 for r in records if 'x' in r),
            'withPhoto': sum(1 for r in records if r['ph']),
            'lonRange': [geo['min_lon'], geo['max_lon']],
            'latRange': [geo['min_lat'], geo['max_lat']],
            'basemapBounds': [list(south_west), list(north_east)],
        },
        'langs': langs_meta,
        'fields': DETAIL_FIELDS,
    }
    (HERE / 'data.js').write_text(
        'window.LLMAP_DATA = ' + json.dumps(payload, ensure_ascii=False,
                                            separators=(',', ':')) + ';\n',
        encoding='utf-8')

    # basemap.js: 既存の 05-basemap.svg の中身をそのまま流用（同一投影）
    svg = (HERE.parent / 'visualization-sample' / 'svg-layers'
           / '05-basemap.svg').read_text(encoding='utf-8')
    body = re.sub(r'^.*?<svg[^>]*>\s*', '', svg, flags=re.S)
    body = re.sub(r'</svg>\s*$', '', body, flags=re.S)
    body = re.sub(r'<title>.*?</title>\s*', '', body, flags=re.S)
    (HERE / 'basemap.js').write_text(
        'window.LLMAP_BASEMAP = ' + json.dumps(body, ensure_ascii=False)
        + ';\n', encoding='utf-8')

    # index.html はテンプレートの複製（テンプレート編集 → 再ビルドで反映）
    (HERE / 'index.html').write_text(
        (HERE / 'web-viewer.template.html').read_text(encoding='utf-8'),
        encoding='utf-8')

    size_mb = sum(f.stat().st_size for f in (HERE / 'thumbs').glob('*.jpg')) / 1e6
    print(json.dumps(dict(records=len(records), withGps=payload['meta']['withGps'],
                          thumbs=dict(made=made, reused=reused, missing=missing),
                          thumbsMB=round(size_mb, 1)), ensure_ascii=False))


if __name__ == '__main__':
    main()
