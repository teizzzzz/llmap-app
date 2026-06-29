/// 設定の永続化と設定画面。
/// - backend URL（Android は PC の LAN IP を入れる）
/// - AI 自動識別の有効/無効・プロバイダ・APIキー
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBaseUrl = 'backend_base_url';
const _kAiEnabled = 'ai_enabled';
const _kAiProvider = 'ai_provider';
const _kAiKey = 'ai_api_key';
const defaultBaseUrl = 'http://localhost:8000';

Future<String> loadBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
}

Future<void> saveBaseUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kBaseUrl, url.trim());
}

class AiConfig {
  bool enabled;
  String provider; // 'claude' | 'gemini'
  String apiKey;
  AiConfig({this.enabled = false, this.provider = 'claude', this.apiKey = ''});
}

Future<AiConfig> loadAiConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return AiConfig(
    enabled: prefs.getBool(_kAiEnabled) ?? false,
    provider: prefs.getString(_kAiProvider) ?? 'claude',
    apiKey: prefs.getString(_kAiKey) ?? '',
  );
}

Future<void> saveAiConfig(AiConfig c) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kAiEnabled, c.enabled);
  await prefs.setString(_kAiProvider, c.provider);
  await prefs.setString(_kAiKey, c.apiKey.trim());
}

/// 設定画面。保存すると更新後の (baseUrl, AiConfig) を返す。
class SettingsScreen extends StatefulWidget {
  final String baseUrl;
  final AiConfig ai;
  const SettingsScreen({super.key, required this.baseUrl, required this.ai});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url =
      TextEditingController(text: widget.baseUrl);
  late final TextEditingController _key =
      TextEditingController(text: widget.ai.apiKey);
  late bool _aiEnabled = widget.ai.enabled;
  late String _provider = widget.ai.provider;
  bool _showKey = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, (
      baseUrl: _url.text.trim(),
      ai: AiConfig(
        enabled: _aiEnabled,
        provider: _provider,
        apiKey: _key.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('后端 URL',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              hintText: 'http://192.168.x.x:8000',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Windows: http://localhost:8000 ／ Androidエミュ: http://10.0.2.2:8000 ／'
            ' 実機: http://<PCのLAN IP>:8000',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI自動識別',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('オンにすると、框选した各景観に入ると自動で字段を識別します'),
            value: _aiEnabled,
            onChanged: (v) => setState(() => _aiEnabled = v),
          ),
          if (_aiEnabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: 'プロバイダ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'claude', child: Text('Claude')),
                DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
              ],
              onChanged: (v) => setState(() => _provider = v ?? 'claude'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'API キー',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                      _showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('キーは端末内にのみ保存され、判定時に各社AI(Claude/Gemini)へ'
                '直接送信されます（PC不要）。',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
