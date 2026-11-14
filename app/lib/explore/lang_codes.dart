/// 言語の正準値（日本語名: 日本語/英語…）と短いコード（ja/en…）の対応。
/// 端末の記録は日本語名、llmap-view の探索データはコードで持つため、
/// 探索・地図・详情ではコードに揃えて扱い、色は端末スキーマの言語色を使う。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme/tokens.dart';

const Map<String, String> kLangCodeByName = {
  '日本語': 'ja',
  '英語': 'en',
  '中国語': 'zh',
  '韓国語': 'ko',
  'ベトナム語': 'vi',
  'ネパール語': 'ne',
  'その他': 'other',
};

final Map<String, String> kLangNameByCode = {
  for (final e in kLangCodeByName.entries) e.value: e.key,
};

/// 正準値（日本語名）→ コード。未知の値は 'other'。
String langCodeOf(String name) => kLangCodeByName[name.trim()] ?? 'other';

/// 表示名（UI 言語に合わせる）。主要 6 言語以外は探索データの名前かコード。
String langDisplayName(AppLocalizations t, String code, {String? fallback}) =>
    switch (code) {
      'ja' => t.langJa,
      'en' => t.langEn,
      'zh' => t.langZh,
      'ko' => t.langKo,
      'vi' => t.langVi,
      'ne' => t.langNe,
      'other' => t.langOther,
      'none' => t.langNone,
      _ => fallback ?? code.toUpperCase(),
    };

/// 地図ピン・言語チップの色。端末スキーマの言語色（凡例と同じ）を引き、
/// スキーマに無い言語は「その他」の色にする。
Color langColor(AppSchema schema, String code) {
  final name = kLangNameByCode[code] ?? 'その他';
  final hex = schema.languageColors[name] ?? schema.languageColors['その他'];
  return hex == null ? AppColors.textSecondary : parseHexColor(hex);
}
