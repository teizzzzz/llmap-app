import 'package:flutter/foundation.dart';
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
        // Web 試用版を PC の広い画面で開いたとき: スマホの大きさの枠の中に表示する。
        builder: kIsWeb ? (context, child) => _PhoneFrame(child: child!) : null,
        home: HomeScreen(schema: defaultSchema()),
      ),
    );
  }
}

/// PC のブラウザ用: 画面が広いときだけ、中央に 390×844 までの枠を置いてその中で動かす
/// （スマホのブラウザでは全画面のまま）。
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 600) return child;
    final h = (mq.size.height - 32).clamp(480.0, 844.0);
    const w = 390.0;
    return ColoredBox(
      color: const Color(0xFFE9E9E9),
      child: Center(
        child: Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 18)),
            ],
          ),
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(w, h),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
