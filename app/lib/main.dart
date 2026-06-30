import 'package:flutter/material.dart';

import 'api.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'schema_defaults.dart';
import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';
import 'theme/tokens.dart';
import 'version.dart';
import 'widgets/ll/ll.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 保存済みの言語設定を反映（null=システムに従う）。
  localeNotifier.value = await loadLocale();
  runApp(const LLMapApp());
}

class LLMapApp extends StatelessWidget {
  const LLMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) => MaterialApp(
        title: 'LLMap',
        debugShowCheckedModeBanner: false,
        theme: lingscapeTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Boot(),
      ),
    );
  }
}

/// 起動時に backend の疎通と /schema を読み込む。失敗時は再試行。
class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  final api = BackendApi();
  Future<AppSchema>? _future;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    api.baseUrl = await loadBaseUrl();
    _load();
  }

  void _load() => setState(() {
        _future = _resolveSchema();
      });

  /// 後端 /schema を取得。繋がらなければ端末内の既定スキーマで起動する
  /// （PC off でも保存データの閲覧・採集・書き出しを止めない）。
  Future<AppSchema> _resolveSchema() async {
    try {
      return await api.schema();
    } catch (_) {
      return defaultSchema();
    }
  }

  Future<void> _editUrl() async {
    final ai = await loadAiConfig();
    final collector = await loadCollectorId();
    if (!mounted) return;
    final result =
        await Navigator.push<({String baseUrl, AiConfig ai, String collectorId})>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(baseUrl: api.baseUrl, ai: ai, collectorId: collector),
      ),
    );
    if (result == null) return;
    await saveBaseUrl(result.baseUrl);
    await saveAiConfig(result.ai);
    await saveCollectorId(result.collectorId);
    api.baseUrl = result.baseUrl;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<AppSchema>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.backgroundWarm,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LLMap', style: AppText.pageTitle()),
                  const SizedBox(height: 6),
                  Text('${t.appTagline} · $kAppVersion', style: AppText.caption()),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ],
              ),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          // 通常は端末内既定スキーマにフォールバックするため到達しない安全弁。
          return Scaffold(
            backgroundColor: AppColors.backgroundWarm,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 44, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(t.bootOfflineTitle, style: AppText.sectionTitle()),
                    const SizedBox(height: 6),
                    Text(t.bootOfflineBody,
                        textAlign: TextAlign.center, style: AppText.caption()),
                    const SizedBox(height: 20),
                    LLPrimaryButton(
                        label: t.retry, expand: false, onPressed: _load),
                    const SizedBox(height: 8),
                    LLSecondaryButton(
                        label: t.settings, expand: false, onPressed: _editUrl),
                  ],
                ),
              ),
            ),
          );
        }
        return HomeScreen(api: api, schema: snap.data!);
      },
    );
  }
}
