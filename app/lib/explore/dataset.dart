/// 探索データ（llmap-view の公開データ）の読み込み。
/// llmap-view フォルダ（NAS や PC 上の静的サイト）の `data/data.js` と
/// `thumbs/<写真>` を HTTP で読む。アドレスは設定画面で入力（空なら探索は
/// 端末の記録だけになる）。データは読み取り専用で、端末の記録とは混ぜない。
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kExploreUrl = 'explore_data_url';

Future<String> loadExploreUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kExploreUrl) ?? '';
  // Web 試用版: 未設定なら、同じサイトに置いた見本の探索データ（./explore-data）を使う。
  if (saved.trim().isEmpty && kIsWeb) {
    return Uri.base.resolve('explore-data').toString();
  }
  return saved;
}

Future<void> saveExploreUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kExploreUrl, url.trim());
}

/// 末尾の `/`・`index.html` を落とし、スキーム無しなら http:// を補う。
String normalizeExploreUrl(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return '';
  if (!u.contains('://')) u = 'http://$u';
  u = u.replaceFirst(RegExp(r'/index\.html?$'), '');
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// 調色板の 1 色（data.js の pal: [hex, 面積比, L, a, b, 色名]。Lab は OKLab）。
class PalColor {
  final String hex;
  final double share;
  final double l, a, b;
  const PalColor(this.hex, this.share, this.l, this.a, this.b);

  double distTo(PalColor o) {
    final dl = l - o.l, da = a - o.a, db = b - o.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }
}

/// llmap-view の 1 レコード（data.js の短縮キーをそのまま写す）。
class LlvRecord {
  final int index; // data.js 内の位置（nb＝関連写真の参照に使う）
  final String id;
  final String displayId;
  final String photo; // thumbs/ 内のファイル名
  final String time; // 'YYYY-MM-DD HH:MM:SS'
  final List<String> main; // 主要言語コード
  final List<String> aux; // 補助言語コード
  final Map<String, String> fields; // rel/car/pos/tmp/rd/dis/q
  final String note;
  final double? lat;
  final double? lng;
  final String colorName; // red/…/black
  final String repColor; // 代表色 #rrggbb
  final double repShare; // 代表色の面積比
  final bool chromatic;
  final double vivid; // cf: 鮮やかさ 0..1
  final List<int> neighbors; // nb: 色板が近い写真（index）
  final List<PalColor> palette;
  final int spectrum; // sp: 色相スペクトル順
  final double lightness; // L
  final ({double x, double y})? wheelPos; // wh: 色轮上の位置（タイル単位）
  final ({double x, double y})? hueLightPos; // hl: 色相×明度の位置

  const LlvRecord({
    required this.index,
    required this.id,
    required this.displayId,
    required this.photo,
    required this.time,
    required this.main,
    required this.aux,
    required this.fields,
    required this.note,
    required this.lat,
    required this.lng,
    required this.colorName,
    required this.repColor,
    required this.repShare,
    required this.chromatic,
    required this.vivid,
    required this.neighbors,
    required this.palette,
    required this.spectrum,
    required this.lightness,
    required this.wheelPos,
    required this.hueLightPos,
  });

  /// llmap-view の cloudScore と同じ「見栄え順」。テーマ内の並びに使う。
  double get showcaseScore =>
      vivid * 0.7 + (chromatic ? 0.3 : 0) + repShare * 0.2;

  factory LlvRecord.fromJson(int index, Map<String, dynamic> j) {
    final pal = (j['pal'] as List?) ?? const [];
    final rep = (j['rep'] as num?)?.toInt() ?? 0;
    final repEntry = rep < pal.length ? pal[rep] as List : null;
    List<String> strs(Object? v) =>
        (v as List? ?? const []).map((e) => e.toString()).toList();
    double? num_(Object? v) => (v as num?)?.toDouble();
    ({double x, double y})? pos(Object? v) {
      final l = v as List?;
      if (l == null || l.length < 2) return null;
      return (x: (l[0] as num).toDouble(), y: (l[1] as num).toDouble());
    }

    return LlvRecord(
      index: index,
      id: (j['id'] ?? '').toString(),
      displayId: (j['d'] ?? j['id'] ?? '').toString(),
      photo: (j['ph'] ?? '').toString(),
      time: (j['t'] ?? '').toString(),
      main: strs(j['main']),
      aux: strs(j['aux']),
      fields: (j['f'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v ?? '').toString()),
      ),
      note: (j['note'] ?? '').toString(),
      lat: num_(j['lat']),
      lng: num_(j['lon']),
      colorName: (j['cn'] ?? '').toString(),
      repColor: repEntry == null ? '#c6c6c6' : repEntry[0].toString(),
      repShare: repEntry == null || repEntry.length < 2
          ? 0
          : (repEntry[1] as num).toDouble(),
      chromatic: j['chr'] == true,
      vivid: num_(j['cf']) ?? 0,
      neighbors: (j['nb'] as List? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      palette: [
        for (final e in pal)
          if (e is List && e.length >= 5)
            PalColor(
              e[0].toString(),
              (e[1] as num).toDouble(),
              (e[2] as num).toDouble(),
              (e[3] as num).toDouble(),
              (e[4] as num).toDouble(),
            ),
      ],
      spectrum: (j['sp'] as num?)?.toInt() ?? index,
      lightness: num_(j['L']) ?? 0.5,
      wheelPos: pos(j['wh']),
      hueLightPos: pos(j['hl']),
    );
  }
}

class ExploreDataset {
  final String baseUrl;
  final List<LlvRecord> records;
  final Map<String, String> langNames; // コード → データ側の名前（予備表示用）
  final List<String> colorNames;

  /// 全写真を 1 枚に並べた縮小画像（漫游画布を一度に描くため）。
  /// records の index 順に tile×tile の正方形が cols 列で並ぶ。
  final String? atlasFile;
  final int atlasTile;
  final int atlasCols;

  const ExploreDataset({
    required this.baseUrl,
    required this.records,
    required this.langNames,
    required this.colorNames,
    this.atlasFile,
    this.atlasTile = 64,
    this.atlasCols = 64,
  });

  String thumbUrl(LlvRecord r) =>
      '$baseUrl/thumbs/${Uri.encodeComponent(r.photo)}';

  String? get atlasUrl => atlasFile == null ? null : '$baseUrl/$atlasFile';
}

/// `<base>/data/data.js` を取得して解析する。失敗時は例外（呼び出し側で表示）。
Future<ExploreDataset> fetchExploreDataset(String rawUrl) async {
  final base = normalizeExploreUrl(rawUrl);
  if (base.isEmpty) throw const FormatException('empty url');
  final res = await http
      .get(Uri.parse('$base/data/data.js'))
      .timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) {
    throw http.ClientException('HTTP ${res.statusCode}');
  }
  // 4〜5MB の JSON を UI スレッドで解かない。
  final parsed = await compute(parseLlvDataJs, utf8.decode(res.bodyBytes));
  return ExploreDataset(
    baseUrl: base,
    records: parsed.records,
    langNames: parsed.langNames,
    colorNames: parsed.colorNames,
    atlasFile: parsed.atlas?.file,
    atlasTile: parsed.atlas?.tile ?? 64,
    atlasCols: parsed.atlas?.cols ?? 64,
  );
}

typedef LlvParsed = ({
  List<LlvRecord> records,
  Map<String, String> langNames,
  List<String> colorNames,
  ({String file, int tile, int cols})? atlas,
});

/// `window.LLV_DATA = {...};` から JSON 部分を取り出して解析する。
LlvParsed parseLlvDataJs(String src) {
  final start = src.indexOf('{');
  final end = src.lastIndexOf('}');
  if (start < 0 || end <= start) throw const FormatException('data.js');
  final d = jsonDecode(src.substring(start, end + 1)) as Map<String, dynamic>;
  final list = (d['records'] as List? ?? const []);
  final langs = (d['langs'] as Map? ?? const {});
  return (
    records: [
      for (var i = 0; i < list.length; i++)
        LlvRecord.fromJson(i, list[i] as Map<String, dynamic>),
    ],
    langNames: {
      for (final e in langs.entries)
        e.key.toString(): ((e.value as Map?)?['name'] ?? e.key).toString(),
    },
    colorNames: (d['colorNames'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    atlas: switch (d['atlas']) {
      {
        'file': final String f,
        'tile': final num tile,
        'cols': final num cols,
      } =>
        (file: f, tile: tile.toInt(), cols: cols.toInt()),
      _ => null,
    },
  );
}
