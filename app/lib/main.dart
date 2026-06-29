import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'schema_defaults.dart';
import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() {
  runApp(const LLMapApp());
}

class LLMapApp extends StatelessWidget {
  const LLMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LLMap 採集',
      debugShowCheckedModeBanner: false,
      theme: lingscapeTheme(),
      home: const _Boot(),
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
    if (!mounted) return;
    final result = await Navigator.push<({String baseUrl, AiConfig ai})>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(baseUrl: api.baseUrl, ai: ai),
      ),
    );
    if (result == null) return;
    await saveBaseUrl(result.baseUrl);
    await saveAiConfig(result.ai);
    api.baseUrl = result.baseUrl;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSchema>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('后端に接続できません\n${api.baseUrl}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('backend を起動してください:\n'
                      'uvicorn app.main:app --port 8000',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _editUrl,
                        icon: const Icon(Icons.settings),
                        label: const Text('URL設定'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: _load, child: const Text('再試行')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return HomeScreen(api: api, schema: snap.data!);
      },
    );
  }
}
