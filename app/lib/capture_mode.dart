/// 採集モード（quick / standard / research）。
/// 3モードは同一の Sign データ構造・同一の首页を共用し、
/// **框选の後**のフローと表単の複雑さだけが変わる:
/// - quick    : 框选 → 直接保存（字段は後で補完）
/// - standard : 框选 → 簡易言語選択（既定モード。Lingscape 相当）
/// - research : 框选 → 完全な研究字段表単（既存 FieldsScreen）
/// 本機のアプリ設定であり、権限/アカウントの仕組みではない。
library;

import 'l10n/app_localizations.dart';

enum CaptureMode { quick, standard, research }

extension CaptureModeX on CaptureMode {
  /// レコードの EntryMode に書く値。
  String get entryMode => name;

  /// 採番直後の DataStatus 初期値（_status は常に pending から始まる）。
  /// quick=raw（現場素材のみ）/ standard=submitted（提交済）/
  /// research=submitted（校閲保存で reviewed へ昇格）。
  String get initialDataStatus =>
      this == CaptureMode.quick ? 'raw' : 'submitted';

  String label(AppLocalizations t) => switch (this) {
        CaptureMode.quick => t.modeQuick,
        CaptureMode.standard => t.modeStandard,
        CaptureMode.research => t.modeResearch,
      };

  String description(AppLocalizations t) => switch (this) {
        CaptureMode.quick => t.modeQuickDesc,
        CaptureMode.standard => t.modeStandardDesc,
        CaptureMode.research => t.modeResearchDesc,
      };
}

/// 保存値 → モード。未知値・未設定は standard（既定モード）。
CaptureMode captureModeFrom(String? value) => switch (value) {
      'quick' => CaptureMode.quick,
      'research' => CaptureMode.research,
      _ => CaptureMode.standard,
    };
