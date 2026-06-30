/// データモデル。backend(/schema, /extract) と CSV 標準字段に対応。
library;

/// 複数選択字段（"日本語/韓国語" など）を個々の値に分割する。
/// 区切りは「/・、,」を許容し、空と「—」は除外する。
List<String> splitMulti(String v) => v
    .split(RegExp(r'[/・、,]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty && e != '—')
    .toList();

/// 全景写真上での框选矩形（0..1 の相対座標）。1枚に複数 = 1图多个sign。
class CropRegion {
  String suffix; // a, b, c ...
  double x, y, w, h;
  CropRegion({
    required this.suffix,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Map<String, dynamic> toJson() => {
        'suffix': suffix,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };
}

/// CSV 標準字段に対応する1レコード。柔軟性のため Map で保持する。
class Sign {
  final Map<String, dynamic> data;
  Sign(this.data);

  factory Sign.fromJson(Map<String, dynamic> json) =>
      Sign(Map<String, dynamic>.from(json));

  String get id => (data['SignID'] ?? '').toString();
  String get status => (data['_status'] ?? 'pending').toString();
  String get name => (data['名称'] ?? '').toString();
  String get fileName => (data['写真ファイル名'] ?? '').toString();
  double? get lat => _toDouble(data['緯度']);
  double? get lng => _toDouble(data['経度']);
  String get mainLang => (data['主要言語'] ?? '').toString();

  /// 多選/併記の先頭言語。地図ピン色など代表値が要る箇所に使う。
  String get mainLangPrimary {
    final parts = splitMulti(mainLang);
    return parts.isEmpty ? '' : parts.first;
  }

  String get(String key) => (data[key] ?? '').toString();
  void set(String key, String value) => data[key] = value;

  Map<String, dynamic> toJson() => data;

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// backend /schema の応答。フォーム選択肢・地図色・標準表頭を保持。
class AppSchema {
  final List<String> csvHeader;
  final List<String> statusValues;
  final Map<String, List<String>> enums;
  final List<String> aiFields;
  final Map<String, String> languageColors;

  /// 複数選択かつ自由追加できる字段（フォームを multi-select で描画）。
  final Set<String> multiFields;

  AppSchema({
    required this.csvHeader,
    required this.statusValues,
    required this.enums,
    required this.aiFields,
    required this.languageColors,
    this.multiFields = const {},
  });

  factory AppSchema.fromJson(Map<String, dynamic> j) => AppSchema(
        csvHeader: List<String>.from(j['csv_header'] ?? const []),
        statusValues: List<String>.from(j['status_values'] ?? const []),
        enums: (j['enums'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ),
        aiFields: List<String>.from(j['ai_fields'] ?? const []),
        languageColors: (j['language_colors'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
        multiFields: Set<String>.from(j['multi_fields'] ?? const []),
      );

  /// フォームに出さない（システム/自動生成）字段。
  static const systemFields = {
    'SignID', '_status', '写真ID', '写真ファイル名', '全景写真ファイル名',
    '緯度', '経度', '採集日時',
  };

  /// 手動/AI 入力対象の字段（表示順は csvHeader 準拠）。
  List<String> get editableFields =>
      csvHeader.where((f) => !systemFields.contains(f)).toList();
}
