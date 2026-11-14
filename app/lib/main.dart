import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'schema_defaults.dart';
import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 保存済みの言語設定を反映（null=システムに従う）。
  localeNotifier.value = await loadLocale();
  runApp(const LLMapApp());
}

/// 手機端は後端を使わない（採集・保存・AI・書き出しはすべて端末内で完結）。
/// 字段定義は端末内の既定スキーマ（schema_defaults.dart）をそのまま使う。
class LLMapApp extends StatelessWidget {
  const LLMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) => MaterialApp(
        title: 'LLMap',
        debugShowCheckedModeBanner: false,
        theme: llmapTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(schema: defaultSchema()),
      ),
    );
  }
}
