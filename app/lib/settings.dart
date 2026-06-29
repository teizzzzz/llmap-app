/// 設定の永続化と設定画面。
/// - backend URL（Android は PC の LAN IP を入れる）
/// - AI 自動識別の有効/無効・プロバイダ・APIキー
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/tokens.dart';
import 'widgets/ll/ll.dart';

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
      appBar: AppBar(title: const Text('项目设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── AI 自动识别 ──
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.accentTerracotta,
                  title: Text('AI 自动识别', style: AppText.sectionTitle()),
                  subtitle: Text('开启后，进入每个框选标志时自动识别字段。',
                      style: AppText.caption()),
                  value: _aiEnabled,
                  onChanged: (v) => setState(() => _aiEnabled = v),
                ),
                if (_aiEnabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  LLFormField(
                    label: '服务商',
                    child: DropdownButtonFormField<String>(
                      initialValue: _provider,
                      items: const [
                        DropdownMenuItem(value: 'claude', child: Text('Claude')),
                        DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                      ],
                      onChanged: (v) =>
                          setState(() => _provider = v ?? 'claude'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LLFormField(
                    label: 'API 密钥',
                    child: TextField(
                      controller: _key,
                      obscureText: !_showKey,
                      decoration: InputDecoration(
                        hintText: 'sk-...',
                        suffixIcon: IconButton(
                          icon: Icon(_showKey
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showKey = !_showKey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('密钥仅保存在本机，识别时直接发送给各家 AI（Claude / Gemini），无需 PC。',
                      style: AppText.caption()),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 后端地址（可选・进阶） ──
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('后端地址（可选）', style: AppText.sectionTitle()),
                const SizedBox(height: AppSpacing.xs),
                Text('日常采集无需后端。仅在使用旧版后端流程时填写。',
                    style: AppText.caption()),
                const SizedBox(height: AppSpacing.md),
                LLFormField(
                  label: '后端 URL',
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                        hintText: 'http://192.168.x.x:8000'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Windows: http://localhost:8000 ／ 模拟器: http://10.0.2.2:8000 '
                    '／ 真机: http://<PC 的局域网 IP>:8000',
                    style: AppText.caption()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          LLPrimaryButton(label: '保存设置', icon: Icons.check, onPressed: _save),
        ],
      ),
    );
  }
}
