/// データモデル。backend(/schema, /extract) と CSV 標準字段に対応。
library;

/// _status（端末内の処理状態）→ DataStatus（Research Console の審核状態）対応。
/// 端末は _status を正、DataStatus を Console 互換の派生値として常に併記する。
const Map<String, String> kDataStatusMap = {
  'pending': 'raw',
  'ai': 'ai_drafted',
  'human-reviewed': 'reviewed',
  'final': 'verified',
};

/// _status に対応する DataStatus。未知値は raw 扱い。
String dataStatusFor(String status) => kDataStatusMap[status] ?? 'raw';

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

  /// CaptureID（1回の撮影イベントの一意ID）。旧データは 写真ID にフォールバック。
  String get captureId {
    final v = (data['CaptureID'] ?? '').toString();
    return v.isNotEmpty ? v : (data['写真ID'] ?? '').toString();
  }

  /// 表示用ID（AREA-YYYYMMDD-SEQ-suffix）。旧データは SignID にフォールバック。
  String get displayId {
    final v = (data['DisplayID'] ?? '').toString();
    return v.isNotEmpty ? v : id;
  }

  /// 元写真（原始完整写真）のファイル名。旧データは 全景写真ファイル名 にフォールバック。
  String get sourceFileName {
    final v = (data['元写真ファイル名'] ?? '').toString();
    return v.isNotEmpty ? v : (data['全景写真ファイル名'] ?? '').toString();
  }

  /// 同一写真内の識別子（a/b/c…）。旧データは SignID 末尾から推定する。
  String get cropSuffix {
    final v = (data['CropSuffix'] ?? '').toString();
    if (v.isNotEmpty) return v;
    final parts = id.split('-');
    return parts.isEmpty ? '' : parts.last;
  }

  /// 採集者ID。旧データには無い（空になる）。
  String get collectorId => (data['採集者ID'] ?? '').toString();

  /// 一覧・地図用の短い表示ラベル（例 "OOK #008-a"）。長い CaptureID を出さない。
  /// 新字段が無い旧データは DisplayID（=SignID）にフォールバック。
  String get shortLabel {
    final area = (data['地区コード'] ?? '').toString();
    final seq = (data['LocalSeq'] ?? '').toString();
    if (area.isNotEmpty && seq.isNotEmpty) {
      final n = int.tryParse(seq);
      final s = n != null ? n.toString().padLeft(3, '0') : seq;
      return '$area #$s-$cropSuffix';
    }
    return displayId;
  }
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

  /// _status を更新し、DataStatus（Console 互換の派生値）も同時に揃える。
  /// 状態遷移は必ずこれを使う（_status 直接 set だと DataStatus が古くなる）。
  void setStatus(String status) {
    data['_status'] = status;
    data['DataStatus'] = dataStatusFor(status);
  }

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
    'SignID', '_status',
    'CaptureID', 'DisplayID', '採集者ID', '地区コード', 'LocalSeq',
    'CropSuffix', 'CropRect',
    '写真ID', '写真ファイル名', '元写真ファイル名', '全景写真ファイル名',
    '緯度', '経度', '採集日時',
    'EntryMode', 'DataStatus', 'SchemaVersion', 'AppVersion',
  };

  /// 手動/AI 入力対象の字段（表示順は csvHeader 準拠）。
  List<String> get editableFields =>
      csvHeader.where((f) => !systemFields.contains(f)).toList();
}
