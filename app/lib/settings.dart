/// 設定の永続化と設定画面。
/// - backend URL（Android は PC の LAN IP を入れる）
/// - AI 自動識別の有効/無効・プロバイダ・APIキー
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'theme/tokens.dart';
import 'widgets/ll/ll.dart';

const _kBaseUrl = 'backend_base_url';
const _kAiEnabled = 'ai_enabled';
const _kAiProvider = 'ai_provider';
const _kAiKey = 'ai_api_key';
const _kLocale = 'app_locale';
const defaultBaseUrl = 'http://localhost:8000';

/// アプリ言語。null = システムに従う。MaterialApp はこれを購読して再構築する。
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

Future<Locale?> loadLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final c = prefs.getString(_kLocale);
  if (c == null || c == 'system') return null;
  return Locale(c);
}

/// 現在の選択コード（'system' | 'zh' | 'ja' | 'en'）。
String currentLocaleCode() => localeNotifier.value?.languageCode ?? 'system';

/// 言語を適用し保存。code は 'system' / 'zh' / 'ja' / 'en'。
Future<void> applyLocale(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLocale, code);
  localeNotifier.value = code == 'system' ? null : Locale(code);
}

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
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.projectSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── 言語 / Language ──
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.language, style: AppText.sectionTitle()),
                const SizedBox(height: AppSpacing.sm),
                _langOption(t.languageSystem, 'system'),
                _langOption('简体中文', 'zh'),
                _langOption('日本語', 'ja'),
                _langOption('English', 'en'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── AI 自动识别 ──
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.accentTerracotta,
                  title: Text(t.aiAuto, style: AppText.sectionTitle()),
                  subtitle: Text(t.aiAutoSub, style: AppText.caption()),
                  value: _aiEnabled,
                  onChanged: (v) => setState(() => _aiEnabled = v),
                ),
                if (_aiEnabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  LLFormField(
                    label: t.provider,
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
                    label: t.apiKey,
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
                  Text(t.apiKeyNote, style: AppText.caption()),
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
                Text(t.backendOptional, style: AppText.sectionTitle()),
                const SizedBox(height: AppSpacing.xs),
                Text(t.backendNote, style: AppText.caption()),
                const SizedBox(height: AppSpacing.md),
                LLFormField(
                  label: t.backendUrl,
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                        hintText: 'http://192.168.x.x:8000'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(t.backendHint, style: AppText.caption()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          LLPrimaryButton(
              label: t.saveSettings, icon: Icons.check, onPressed: _save),
        ],
      ),
    );
  }

  Widget _langOption(String label, String code) {
    final selected = currentLocaleCode() == code;
    return InkWell(
      onTap: () async {
        await applyLocale(code);
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accentTerracotta : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: AppText.body().copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
