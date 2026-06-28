import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'screens/home_screen.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFc84b31),
        scaffoldBackgroundColor: const Color(0xFFf5f2ed),
      ),
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
    _load();
  }

  void _load() => setState(() {
        _future = api.schema();
      });

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
                  FilledButton(onPressed: _load, child: const Text('再試行')),
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
