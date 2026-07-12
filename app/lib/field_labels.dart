/// 研究字段・_status の**表示ラベル**マッピング（UI 表示層のみ）。
/// データのキー・値は日本語正準（CSV/Dataset Package/Console と共通）のまま
/// 一切変えない。未知のキー/値はそのまま表示する（自定义字段への備え）。
library;

import 'l10n/app_localizations.dart';

/// 字段キー → 本地化ラベル。SignForm（研究/編集）と StandardFieldsScreen で共用。
String fieldLabel(AppLocalizations t, String field) => switch (field) {
      '名称' => t.fieldName,
      '文字性' => t.fieldTextuality,
      '主要言語' => t.mainLanguage,
      '補助言語' => t.subLanguage,
      '装飾の言語' => t.fieldDecorLang,
      '文字体系' => t.fieldScript,
      '多言語関係' => t.multilingual,
      '担体類型' => t.carrier,
      '空間階層' => t.fieldSpatial,
      '時間性' => t.fieldTemporality,
      '可読性' => t.fieldLegibility,
      '重ね書き' => t.fieldOverwrite,
      '設置主体' => t.operator,
      'ディスコース類型' => t.fieldDiscourse,
      '製作品質' => t.fieldQuality,
      '備考' => t.fieldNote,
      _ => field,
    };

/// _status（内部値 pending/ai/human-reviewed/final）の表示ラベル。
String statusLabel(AppLocalizations t, String status) => switch (status) {
      'pending' => t.statusPending,
      'ai' => t.statusAi,
      'human-reviewed' => t.statusHumanReviewed,
      'final' => t.statusFinal,
      _ => status,
    };
