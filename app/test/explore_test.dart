import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/explore/dataset.dart';
import 'package:llmap_app/explore/lang_codes.dart';
import 'package:llmap_app/explore/relations.dart';
import 'package:llmap_app/explore/themes.dart';

/// 小さな data.js（llmap-view と同じ形）。
Map<String, Object?> rec(
  String id, {
  List<String> main = const ['ja'],
  List<String> aux = const [],
  Map<String, String> f = const {},
  String cn = 'gray',
  bool chr = false,
  double cf = 0.2,
  double lat = 35.7010,
  double lon = 139.7000,
  List<int> nb = const [],
  List<List<Object>> pal = const [
    ['#808080', 1.0, 0.6, 0.0, 0.0, 'gray'],
  ],
}) =>
    {
      'id': id,
      'd': id,
      'ph': '$id.jpg',
      't': '2026-07-01 12:00:00',
      'main': main,
      'aux': aux,
      'f': f,
      'note': '',
      'lat': lat,
      'lon': lon,
      'pal': pal,
      'rep': 0,
      'cn': cn,
      'chr': chr,
      'cf': cf,
      'sp': 0,
      'L': 0.5,
      'wh': [1, 2],
      'hl': [3, 4],
      'nb': nb,
    };

String dataJs(List<Map<String, Object?>> records) {
  final body = {
    'records': records,
    'langs': {
      'ja': {'name': '日本語', 'color': '#b84f38'},
    },
    'atlas': {'file': 'data/atlas.webp', 'tile': 64, 'cols': 64},
    'colorNames': ['red', 'gray', 'black'],
    'built': '2026-11-10',
  };
  return 'window.LLV_DATA = ${_json(body)};';
}

String _json(Object? v) {
  // jsonEncode を避けて依存を増やさない（テスト用の最小実装）。
  if (v == null) return 'null';
  if (v is String) return '"${v.replaceAll('"', r'\"')}"';
  if (v is num || v is bool) return '$v';
  if (v is List) return '[${v.map(_json).join(',')}]';
  if (v is Map) {
    return '{${v.entries.map((e) => '${_json(e.key)}:${_json(e.value)}').join(',')}}';
  }
  throw ArgumentError(v);
}

ExploreDataset dataset(List<Map<String, Object?>> records) {
  final p = parseLlvDataJs(dataJs(records));
  return ExploreDataset(
    baseUrl: 'http://x',
    records: p.records,
    langNames: p.langNames,
    colorNames: p.colorNames,
    atlasFile: p.atlas?.file,
  );
}

void main() {
  test('normalizeExploreUrl: スキーム補完・末尾 / と index.html を除去', () {
    expect(normalizeExploreUrl(''), '');
    expect(normalizeExploreUrl(' 192.168.1.7:8765/ '), 'http://192.168.1.7:8765');
    expect(normalizeExploreUrl('http://nas/llmap/index.html'),
        'http://nas/llmap');
  });

  test('data.js を解析: 短縮キー・代表色・atlas・位置', () {
    final ds = dataset([
      rec('OOK-1-a', main: ['zh'], aux: ['ja', 'en'], f: {'car': '夹心板'}),
    ]);
    final r = ds.records.single;
    expect(r.main, ['zh']);
    expect(r.aux, ['ja', 'en']);
    expect(r.fields['car'], '夹心板');
    expect(r.repColor, '#808080');
    expect(r.palette.single.l, 0.6);
    expect(r.wheelPos, (x: 1.0, y: 2.0));
    expect(r.hueLightPos, (x: 3.0, y: 4.0));
    expect(ds.atlasUrl, 'http://x/data/atlas.webp');
    expect(ds.thumbUrl(r), 'http://x/thumbs/OOK-1-a.jpg');
    expect(ds.langNames['ja'], '日本語');
  });

  test('言語コード対応: 正準値⇄コード、未知は other', () {
    expect(langCodeOf('中国語'), 'zh');
    expect(langCodeOf('ネパール語'), 'ne');
    expect(langCodeOf('タガログ語'), 'other');
    expect(kLangNameByCode['ko'], '韓国語');
  });

  test('主题: web 版と同じ条件で選ぶ', () {
    final ds = dataset([
      rec('a-a', main: ['zh'], cn: 'red'), // th1
      rec('b-a', main: ['ja'], cn: 'red'), // th1 ではない（中文でない）
      rec('c-a', f: {'q': '手作'}), // th2
      rec('d-a', main: ['vi']), // th6
      rec('e-a', cf: 0.8), // th7
      rec('f-a', f: {'car': '便签'}), // th9
    ]);
    List<String> ids(int theme) => kExploreThemes
        .firstWhere((t) => t.id == theme)
        .pick(ds.records)
        .map((r) => r.id)
        .toList();
    expect(ids(1), ['a-a']);
    expect(ids(2), ['c-a']);
    expect(ids(6), ['d-a']);
    expect(ids(7), ['e-a']);
    expect(ids(9), ['f-a']);
  });

  group('关联（接下来探索）', () {
    late ExploreDataset ds;
    late RelationIndex idx;
    setUp(() {
      ds = dataset([
        // 0,1: 同じ撮影（同一画面）。0 は nb で 3 と色が近い。
        rec('CAP1-a', main: ['ja'], aux: ['en'], nb: [3],
            f: {'dis': '规约性话语', 'car': '夹心板'}),
        rec('CAP1-b', main: ['ja'], aux: ['en'], lat: 35.7011),
        // 2: 0 と言語の組み合わせ・話語×載体が同じ、少し離れた場所。
        rec('CAP2-a', main: ['ja'], aux: ['en'], lat: 35.7020,
            f: {'dis': '规约性话语', 'car': '夹心板'}),
        // 3: 同じ主要言語で鮮やかな赤（颜色反差の候補）。
        rec('CAP3-a', main: ['ja'], chr: true, cn: 'red', lat: 35.7100, pal: [
          ['#ff0000', 1.0, 0.63, 0.22, 0.13, 'red'],
        ]),
        // 4: 主要言語が違う（反差の対象外）。
        rec('CAP4-a', main: ['zh'], chr: true, lat: 35.7200),
      ]);
      idx = RelationIndex(ds);
    });

    Relation? find(int i, RelKind k) {
      for (final r in idx.of(i)) {
        if (r.kind == k) return r;
      }
      return null;
    }

    test('颜色相近 = 事前計算の nb', () {
      expect(find(0, RelKind.color)!.items, [3]);
      expect(find(1, RelKind.color), isNull); // nb 無し
    });

    test('同一画面 = 同じ撮影の他の標識', () {
      expect(find(0, RelKind.scene)!.items, [1]);
      expect(find(2, RelKind.scene), isNull);
    });

    test('就在附近: 同じ撮影を除き近い順', () {
      final near = find(0, RelKind.near)!;
      expect(near.items, [2, 3, 4]);
      expect(near.radiusM, greaterThan(1000));
    });

    test('相同语言组合・相同话语与载体', () {
      expect(find(0, RelKind.lang)!.items.toSet(), {1, 2});
      expect(find(0, RelKind.lang)!.langs, ['ja', 'en']);
      final type = find(0, RelKind.type)!;
      expect(type.items, [2]);
      expect(type.carrier, '夹心板');
    });

    test('颜色反差: 同じ主要言語・有彩色だけ', () {
      final c = find(0, RelKind.contrast)!;
      expect(c.items, [3]);
      expect(c.mainLang, 'ja');
    });

    test('自分の記録向けの就在附近（任意の地点から）', () {
      final near = idx.nearby(35.7101, 139.7000)!;
      expect(near.items.first, 3);
    });
  });
}
