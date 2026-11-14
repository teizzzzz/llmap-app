/// 探索の「主题」。llmap-view の THEMES（キュレーションした筛选プリセット）と
/// 同じ条件・同じ並び（見栄え順）で、手機でも同じテーマが同じ写真で開く。
library;

import '../l10n/app_localizations.dart';
import 'dataset.dart';

class ExploreTheme {
  final int id;
  final bool Function(LlvRecord r) matches;
  const ExploreTheme(this.id, this.matches);

  String title(AppLocalizations t) => switch (id) {
    1 => t.theme1Title,
    2 => t.theme2Title,
    3 => t.theme3Title,
    4 => t.theme4Title,
    5 => t.theme5Title,
    6 => t.theme6Title,
    7 => t.theme7Title,
    8 => t.theme8Title,
    _ => t.theme9Title,
  };

  String subtitle(AppLocalizations t) => switch (id) {
    1 => t.theme1Sub,
    2 => t.theme2Sub,
    3 => t.theme3Sub,
    4 => t.theme4Sub,
    5 => t.theme5Sub,
    6 => t.theme6Sub,
    7 => t.theme7Sub,
    8 => t.theme8Sub,
    _ => t.theme9Sub,
  };

  /// 条件に合う写真を見栄え順に。
  List<LlvRecord> pick(List<LlvRecord> all) =>
      all.where(matches).toList()
        ..sort((a, b) => b.showcaseScore.compareTo(a.showcaseScore));
}

bool _anyLang(LlvRecord r, Set<String> codes) =>
    (r.main.isEmpty ? const ['none'] : r.main).any(codes.contains);

/// llmap-view app.js の THEMES と同じ 9 件。
final List<ExploreTheme> kExploreThemes = [
  ExploreTheme(1, (r) => _anyLang(r, {'zh'}) && r.colorName == 'red'),
  ExploreTheme(2, (r) => r.fields['q'] == '手作'),
  ExploreTheme(3, (r) => r.fields['tmp'] == '临时·季节性'),
  ExploreTheme(4, (r) => r.fields['dis'] == '规约性话语'),
  ExploreTheme(5, (r) => r.fields['rel'] == '复制型'),
  ExploreTheme(6, (r) => _anyLang(r, {'vi', 'ne'})),
  ExploreTheme(7, (r) => r.vivid >= 0.72),
  ExploreTheme(8, (r) => r.colorName == 'black'),
  ExploreTheme(9, (r) => {'贴纸', '便签'}.contains(r.fields['car'])),
];

/// 色名（data.js の cn）→ 表示名。
String colorDisplayName(AppLocalizations t, String cn) => switch (cn) {
  'red' => t.colorRed,
  'orange' => t.colorOrange,
  'yellow' => t.colorYellow,
  'green' => t.colorGreen,
  'blue' => t.colorBlue,
  'purple' => t.colorPurple,
  'pink' => t.colorPink,
  'brown' => t.colorBrown,
  'white' => t.colorWhite,
  'gray' => t.colorGray,
  'black' => t.colorBlack,
  _ => cn,
};

/// 色名の見本色（llmap-view の CN_SW と同じ値）。
const Map<String, int> kColorSwatch = {
  'red': 0xFFF0281E,
  'orange': 0xFFFF8A00,
  'yellow': 0xFFFFD000,
  'green': 0xFF12B54A,
  'blue': 0xFF1F66FF,
  'purple': 0xFF8A3CFF,
  'pink': 0xFFFF4FA0,
  'brown': 0xFFA0561F,
  'white': 0xFFFFFFFF,
  'gray': 0xFFA2A2A2,
  'black': 0xFF111111,
};
