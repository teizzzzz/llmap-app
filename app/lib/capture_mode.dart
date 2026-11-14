/// 採集モード。設定で選べるのは 2 つ:
/// - quick    : デフォルトモード。写真と地点を優先。框选（しなければ写真全体が
///              1 sign）の後、標識ごとに言語を任意で選んで保存。字段は後で補完。
/// - research : エキスパートモード。框选 → 完全な研究字段表単（FieldsScreen）。
/// standard（旧・既定。框选 → 簡易言語選択）は旧データの EntryMode として
/// 残すだけで、新規の採集では選ばない（保存値 'standard' は quick に読み替え）。
/// 同一の Sign データ構造を共用する本機のアプリ設定（権限の仕組みではない）。
/// 純ロジックのみ（UI ラベルは settings.dart の CaptureModeLabels 拡張にある）。
library;

enum CaptureMode { quick, standard, research }

extension CaptureModeX on CaptureMode {
  /// レコードの EntryMode に書く値。
  String get entryMode => name;

  /// 採番直後の DataStatus 初期値（_status は常に pending から始まる）。
  /// quick=raw（現場素材のみ）/ standard=submitted（提交済）/
  /// research=submitted（校閲保存で reviewed へ昇格）。
  String get initialDataStatus =>
      this == CaptureMode.quick ? 'raw' : 'submitted';
}

/// 保存値 → モード。'research' 以外（未設定・旧 'standard' を含む）は
/// デフォルトモード（quick）。
CaptureMode captureModeFrom(String? value) => switch (value) {
      'research' => CaptureMode.research,
      _ => CaptureMode.quick,
    };
