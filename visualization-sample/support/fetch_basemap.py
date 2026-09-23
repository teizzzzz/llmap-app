"""Fetch an OpenStreetMap vector basemap for the survey extent → 05-basemap.svg.

新大久保車站周辺の道路・鉄道・建物を Overpass API から取得し、
export_svg_layers.py と**同一の投影・同一の画板**（1100x350 viewBox / 550x175 mm）
に描く。生成物は svg-layers/ の他レイヤーと叠放で完全に套准する。

- 取得範囲 = 画板全体を経緯度へ逆投影 + 余白 25 m
- 一度取得した生データは osm-cache.json に保存（再実行時はネット不要）
- 出力は意味別の命名グループ: buildings / roads-casing / roads / railway
  （AI 内で個別に再配色・削除できる。文字ラベルは AI 側で入れる想定）
- データは © OpenStreetMap contributors（ODbL）。図中に帰属表記を含む。

Run: python fetch_basemap.py
"""
from pathlib import Path
import json
import urllib.request

import export_svg_layers as ex

HERE = Path(__file__).resolve().parent
CACHE = HERE / 'osm-cache.json'
# 公共 Overpass 节点は混雑で 504 を返すことがある → 順に試す
OVERPASS_ENDPOINTS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
]
MARGIN_M = 25  # 画板の外側にもこの分だけ地物を取り、縁で道路が切れて見えないように

# 道路の描画幅（メートル。stroke = 幅 x s で viewBox 単位へ）
ROAD_W = {'motorway': 12, 'trunk': 11, 'primary': 10, 'secondary': 8, 'tertiary': 7,
          'unclassified': 5.5, 'residential': 5.5, 'living_street': 5,
          'service': 3.5, 'pedestrian': 4, 'footway': 2, 'path': 2, 'cycleway': 2,
          'steps': 2}
BUILDING_FILL = '#e7e9dd'
ROAD_FILL, ROAD_CASING = '#ffffff', '#d5d8cb'
RAIL_COLOR = '#9aa392'


def artboard_bbox(geo):
    """画板四隅を経緯度へ逆投影し、余白付きの (south, west, north, east) を返す。"""
    inv_x = lambda u: (u - ex.W / 2) / geo['s'] + geo['span_x'] / 2   # noqa: E731
    inv_y = lambda v: (ex.H / 2 + 3 - v) / geo['s'] + geo['span_y'] / 2  # noqa: E731
    m = MARGIN_M
    xs = [inv_x(0) - m, inv_x(ex.W) + m]
    ys = [inv_y(ex.H) - m, inv_y(0) + m]
    west = geo['min_lon'] + min(xs) / geo['mx']
    east = geo['min_lon'] + max(xs) / geo['mx']
    south = geo['min_lat'] + min(ys) / geo['my']
    north = geo['min_lat'] + max(ys) / geo['my']
    return south, west, north, east


def fetch(bbox):
    if CACHE.exists():
        data = json.loads(CACHE.read_text(encoding='utf-8'))
        if data.get('bbox') == list(bbox):
            return data['osm']
    query = (f'[out:json][timeout:90][bbox:{bbox[0]:.6f},{bbox[1]:.6f},{bbox[2]:.6f},{bbox[3]:.6f}];'
             '(way[highway];way[railway];way[building];);(._;>;);out body;')
    last_error = None
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            req = urllib.request.Request(
                endpoint, data=('data=' + urllib.parse.quote(query)).encode(),
                headers={'User-Agent': 'LLMap-graduation-basemap/1.0'})
            with urllib.request.urlopen(req, timeout=120) as resp:
                osm = json.load(resp)
            break
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as err:
            print(f'[fetch] {endpoint} 失败: {err}，尝试下一个节点')
            last_error = err
    else:
        raise SystemExit(f'所有 Overpass 节点均失败，请稍后重试: {last_error}')
    CACHE.write_text(json.dumps(dict(bbox=list(bbox), osm=osm), ensure_ascii=False),
                     encoding='utf-8')
    return osm


def main():
    records = ex.load()
    geo = ex.build_geometry(records)
    bbox = artboard_bbox(geo)
    osm = fetch(bbox)

    nodes = {e['id']: (e['lon'], e['lat']) for e in osm['elements'] if e['type'] == 'node'}

    def project(way):
        pts = []
        for nid in way.get('nodes', []):
            if nid not in nodes:
                continue
            lon, lat = nodes[nid]
            x = (lon - geo['min_lon']) * geo['mx']
            y = (lat - geo['min_lat']) * geo['my']
            pts.append((round(geo['px'](x), 1), round(geo['py'](y), 1)))
        return pts

    def path_d(pts, close=False):
        d = 'M' + 'L'.join(f'{x} {y}' for x, y in pts)
        return d + 'Z' if close else d

    buildings, casings, roads, rails = [], [], [], []
    counts = {'building': 0, 'highway': 0, 'railway': 0}
    for e in osm['elements']:
        if e['type'] != 'way':
            continue
        tags = e.get('tags', {})
        pts = project(e)
        if len(pts) < 2:
            continue
        # 画板から大きく外れる地物は捨てる（余白の分は残す）
        pad = MARGIN_M * geo['s']
        if not any(-pad <= x <= ex.W + pad and -pad <= y <= ex.H + pad for x, y in pts):
            continue
        if 'building' in tags:
            buildings.append(f'<path d="{path_d(pts, close=True)}" fill="{BUILDING_FILL}"/>')
            counts['building'] += 1
        elif 'highway' in tags:
            w = ROAD_W.get(tags['highway'])
            if w is None:
                continue
            stroke = round(w * geo['s'], 1)
            d = path_d(pts)
            casings.append(f'<path d="{d}" fill="none" stroke="{ROAD_CASING}" '
                           f'stroke-width="{round(stroke + 1.6, 1)}" stroke-linecap="round" stroke-linejoin="round"/>')
            roads.append(f'<path d="{d}" fill="none" stroke="{ROAD_FILL}" '
                         f'stroke-width="{stroke}" stroke-linecap="round" stroke-linejoin="round"/>')
            counts['highway'] += 1
        elif 'railway' in tags and tags['railway'] in ('rail', 'light_rail', 'subway'):
            rails.append(f'<path d="{path_d(pts)}" fill="none" stroke="{RAIL_COLOR}" '
                         f'stroke-width="{round(1.5 * geo["s"], 1)}" stroke-dasharray="7 5"/>')
            counts['railway'] += 1

    body = (
        f'<clipPath id="artboard"><rect x="0" y="0" width="{ex.W}" height="{ex.H}"/></clipPath>'
        f'<g clip-path="url(#artboard)">'
        f'<g id="buildings">{"".join(buildings)}</g>'
        f'<g id="roads-casing">{"".join(casings)}</g>'
        f'<g id="roads">{"".join(roads)}</g>'
        f'<g id="railway">{"".join(rails)}</g>'
        f'</g>'
        f'<text x="1060" y="344" text-anchor="end" font-size="8" '
        f'font-family="Helvetica, Arial, sans-serif" fill="#9aa08f" '
        f'id="attribution">&#169; OpenStreetMap contributors</text>')
    out = ex.OUT / '05-basemap.svg'
    ex.OUT.mkdir(exist_ok=True)
    out.write_text(ex.svg_doc('LLMap 新大久保 · 街道底图（OpenStreetMap）', body), encoding='utf-8')
    print(json.dumps(dict(file=str(out), bbox=[round(v, 6) for v in bbox], **counts),
                     ensure_ascii=False))


if __name__ == '__main__':
    main()
