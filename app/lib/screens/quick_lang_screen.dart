/// デフォルトモードの框选後：切り出した標識ごとに「出现了哪些语言」を
/// 任意で選んで、まとめて保存する（主要/補助は区別しない）。
/// 選んだ言語は 主要言語 に多値で入れ、DataStatus=raw のまま（主従の判定は
/// 後の補完・Console の審核で行う）。何も選ばずに保存してもよい。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../explore/lang_codes.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/crop_preview.dart';
import '../widgets/ll/ll.dart';

class QuickLangScreen extends StatefulWidget {
  final AppSchema schema;
  final Uint8List imageBytes;
  final List<Sign> signs;
  final List<CropRegion> regions;

  const QuickLangScreen({
    super.key,
    required this.schema,
    required this.imageBytes,
    required this.signs,
    required this.regions,
  });

  @override
  State<QuickLangScreen> createState() => _QuickLangScreenState();
}

class _QuickLangScreenState extends State<QuickLangScreen> {
  // sign の SignID → 選んだ言語（正準値＝日本語名）
  late final Map<String, Set<String>> _langs = {
    for (final s in widget.signs) s.id: <String>{},
  };

  List<String> get _options => widget.schema.enums['主要言語'] ?? const <String>[];

  CropRegion? _regionFor(Sign sign) {
    for (final r in widget.regions) {
      if (r.suffix == sign.cropSuffix) return r;
    }
    return null;
  }

  void _save() {
    for (final s in widget.signs) {
      final chosen = _langs[s.id]!;
      if (chosen.isNotEmpty) {
        s.set('主要言語', _options.where(chosen.contains).join('/'));
      }
    }
    Navigator.pop(context, widget.signs);
  }

  /// 途中で戻る＝この撮影を破棄（写真の後始末は CropScreen 側が行う）。
  Future<void> _confirmAbandon(bool didPop) async {
    if (didPop) return;
    final t = AppLocalizations.of(context);
    final ok = await showLLDialog<bool>(
      context,
      icon: Icons.help_outline,
      title: t.discardTitle,
      message: t.discardCaptureBody,
      primaryLabel: t.discard,
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: t.cancel,
      onSecondary: () => Navigator.pop(context, false),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final many = widget.signs.length > 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _confirmAbandon(didPop),
      child: Scaffold(
        appBar: AppBar(title: Text(t.quickLangPrompt)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(t.quickHint, style: AppText.caption()),
            ),
            for (final s in widget.signs) ...[
              LLCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CropPreview(
                      imageBytes: widget.imageBytes,
                      region: _regionFor(s),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (many)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                s.cropSuffix.toUpperCase(),
                                style: AppText.sectionTitle(),
                              ),
                            ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final name in _options) _chip(t, s, name),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LLPrimaryButton(
              label: t.quickSave,
              icon: Icons.check,
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(AppLocalizations t, Sign s, String name) {
    final set = _langs[s.id]!;
    final on = set.contains(name);
    return FilterChip(
      avatar: on
          ? null
          : CircleAvatar(
              radius: 5,
              backgroundColor: langColor(widget.schema, langCodeOf(name)),
            ),
      label: Text(langDisplayName(t, langCodeOf(name), fallback: name)),
      selected: on,
      onSelected: (_) => setState(() => on ? set.remove(name) : set.add(name)),
    );
  }
}
