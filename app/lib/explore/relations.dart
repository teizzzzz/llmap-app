/// 照片详情の「接下来探索」：1 枚の写真から 6 種の関連をたどる。
/// llmap-view（app.js relations()）と同じ定義で、同じ写真から同じ関連が出る:
///   颜色相近（色板が近い・事前計算の nb）/ 同一画面（同じ街景写真の他の標識）/
///   就在附近（近い順 24 件）/ 相同语言组合 / 相同话语与载体 /
///   颜色反差（同じ主要言語で色板が最も遠いもの）。
library;

import 'dart:math' as math;

import 'dataset.dart';

enum RelKind { color, scene, near, lang, type, contrast }

class Relation {
  final RelKind kind;
  final List<int> items; // 関連写真の index（先頭が表紙）
  final int radiusM; // near: 対象範囲の半径（m）
  final List<String> langs; // lang: 言語コード（主要→補助）
  final String discourse; // type
  final String carrier; // type
  final String mainLang; // contrast

  const Relation(
    this.kind,
    this.items, {
    this.radiusM = 0,
    this.langs = const [],
    this.discourse = '',
    this.carrier = '',
    this.mainLang = '',
  });
}

/// データセット単位の索引（同画面・言語組合せ・話語×載体のグループ）と結果キャッシュ。
class RelationIndex {
  final ExploreDataset ds;
  late final List<String> _cap = [
    for (final r in ds.records) r.id.replaceFirst(RegExp(r'-[a-z]$'), ''),
  ];
  late final Map<String, List<int>> _capMap = _group(_cap);
  late final List<String> _lk = [
    for (final r in ds.records)
      '${([...r.main]..sort()).join('+')}|${([...r.aux]..sort()).join('+')}',
  ];
  late final Map<String, List<int>> _lkMap = _group(_lk);
  late final List<String> _tk = [
    for (final r in ds.records)
      '${r.fields['dis'] ?? ''}|${r.fields['car'] ?? ''}',
  ];
  late final Map<String, List<int>> _tkMap = _group(_tk);
  final Map<int, List<Relation>> _cache = {};

  RelationIndex(this.ds);

  static Map<String, List<int>> _group(List<String> keys) {
    final m = <String, List<int>>{};
    for (var i = 0; i < keys.length; i++) {
      (m[keys[i]] ??= []).add(i);
    }
    return m;
  }

  // 新大久保付近の緯度での近似距離（m）。web 版と同じ係数。
  static const _mLat = 111320.0;
  static final _mLon = 111320.0 * math.cos(35.7016 * math.pi / 180);

  static double meters(double lat1, double lng1, double lat2, double lng2) {
    final dy = (lat1 - lat2) * _mLat, dx = (lng1 - lng2) * _mLon;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 色板間の距離（a の各色について b の最も近い色との距離を面積比で重み付け）。
  double _palDist(LlvRecord a, LlvRecord b) {
    var s = 0.0;
    for (final p in a.palette) {
      var m = 9.0;
      for (final q in b.palette) {
        m = math.min(m, p.distTo(q));
      }
      s += p.share * m;
    }
    return s;
  }

  static List<int> _shuffled(List<int> xs, int seed) =>
      [...xs]..shuffle(math.Random(seed));

  /// 探索データの写真 [i] の関連（空の関連は含めない）。
  List<Relation> of(int i) => _cache[i] ??= _compute(i);

  List<Relation> _compute(int i) {
    final recs = ds.records;
    final r = recs[i];
    final out = <Relation>[];
    if (r.neighbors.isNotEmpty) {
      out.add(Relation(RelKind.color, [...r.neighbors]));
    }
    final sib = (_capMap[_cap[i]] ?? const <int>[]).where((j) => j != i);
    if (sib.isNotEmpty) out.add(Relation(RelKind.scene, sib.toList()));
    if (r.lat != null && r.lng != null) {
      final near = nearby(r.lat!, r.lng!, exceptCapture: _cap[i]);
      if (near != null) out.add(near);
    }
    if (r.main.isNotEmpty) {
      final same = _lkMap[_lk[i]]!.where((j) => j != i).toList();
      if (same.isNotEmpty) {
        out.add(
          Relation(
            RelKind.lang,
            _shuffled(same, i * 31 + 1),
            langs: [...r.main, ...r.aux],
          ),
        );
      }
    }
    final st = _tkMap[_tk[i]]!.where((j) => j != i).toList();
    if (st.isNotEmpty) {
      out.add(
        Relation(
          RelKind.type,
          _shuffled(st, i * 31 + 2),
          discourse: r.fields['dis'] ?? '',
          carrier: r.fields['car'] ?? '',
        ),
      );
    }
    if (r.main.isNotEmpty) {
      final l0 = r.main.first;
      final cands = <(double, int)>[
        for (var j = 0; j < recs.length; j++)
          if (j != i &&
              recs[j].chromatic &&
              recs[j].main.isNotEmpty &&
              recs[j].main.first == l0)
            (_palDist(r, recs[j]), j),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      if (cands.isNotEmpty) {
        final top = [for (final c in cands.take(60)) c.$2];
        out.add(
          Relation(
            RelKind.contrast,
            _shuffled(top, i * 31 + 3).take(24).toList(),
            mainLang: l0,
          ),
        );
      }
    }
    return out;
  }

  /// ある地点から近い順 24 件（同じ撮影の写真は除く）。自分の記録の
  /// 「就在附近」にも使う。位置を持つ写真が無ければ null。
  Relation? nearby(double lat, double lng, {String? exceptCapture}) {
    final recs = ds.records;
    final cands = <(double, int)>[
      for (var j = 0; j < recs.length; j++)
        if (recs[j].lat != null &&
            recs[j].lng != null &&
            (exceptCapture == null || _cap[j] != exceptCapture))
          (meters(lat, lng, recs[j].lat!, recs[j].lng!), j),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (cands.isEmpty) return null;
    final sel = cands.take(24).toList();
    return Relation(RelKind.near, [
      for (final c in sel) c.$2,
    ], radiusM: math.max(5, sel.last.$1.round()));
  }

  /// 関連写真 [j] と元の地点との距離（就在附近のタグ用）。
  int metersTo(double lat, double lng, int j) {
    final r = ds.records[j];
    if (r.lat == null || r.lng == null) return 0;
    return meters(lat, lng, r.lat!, r.lng!).round();
  }
}
