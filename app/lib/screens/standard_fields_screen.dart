import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../schema_defaults.dart';
import '../theme/tokens.dart';
import '../widgets/crop_preview.dart';
import '../widgets/ll/ll.dart';

/// 標準モードの簡易字段入力（Lingscape 相当）。框选した sign を1つずつ、
/// 「標識に現れる言語」の多選だけで提交できる。展開で少数の官方字段を追加可。
/// FieldsScreen（研究モードの完全表単）とデータ構造は同一で、表示だけ簡素。
class StandardFieldsScreen extends StatefulWidget {
  final AppSchema schema;
  final Uint8List imageBytes;
  final List<Sign> signs;
  final List<CropRegion> regions;

  const StandardFieldsScreen({
    super.key,
    required this.schema,
    required this.imageBytes,
    required this.signs,
    required this.regions,
  });

  @override
  State<StandardFieldsScreen> createState() => _StandardFieldsScreenState();
}

class _StandardFieldsScreenState extends State<StandardFieldsScreen> {
  int _index = 0;
  bool _more = false; // 「＋ 添加更多信息」の展開状態（sign ごとにリセット）
  final List<Sign> _saved = [];

  Sign get _current => widget.signs[_index];
  bool get _isLast => _index >= widget.signs.length - 1;

  /// 言語の選択肢（既定言語＋「不明」）。値は正準値のまま表示する。
  List<String> get _langOptions {
    final base = widget.schema.enums['主要言語'] ?? const <String>[];
    return [...base, if (!base.contains('不明')) '不明'];
  }

  CropRegion? _regionFor(Sign sign) {
    final suffix = sign.cropSuffix;
    for (final r in widget.regions) {
      if (r.suffix == suffix) return r;
    }
    return null;
  }

  /// UI ラベルは本地化文言、data キーは schema の正準キー（混用しない）。
  String _labelFor(AppLocalizations t, String field) => switch (field) {
        '主要言語' => t.mainLanguage,
        '補助言語' => t.subLanguage,
        '文字体系' => t.fieldScript,
        '担体類型' => t.carrier,
        '設置主体' => t.operator,
        '多言語関係' => t.multilingual,
        '備考' => t.fieldNote,
        _ => field,
      };

  /// 提交して次へ。標準モードの状態は _status=pending / DataStatus=submitted の
  /// まま（採番時に設定済み。校閲は Console / 研究モードの仕事）。
  void _save() {
    _saved.add(_current);
    if (_isLast) {
      Navigator.pop(context, _saved);
    } else {
      setState(() {
        _index++;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final total = widget.signs.length;
    final sign = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.fieldsTitle(sign.cropSuffix, _index + 1, total)),
        bottom: total > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / total,
                  minHeight: 4,
                  backgroundColor: AppColors.muted,
                  color: AppColors.accentTerracotta,
                ),
              )
            : null,
      ),
      body: ListView(
        key: ValueKey(sign.id),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LLCard(
            padding: EdgeInsets.zero,
            child: CropPreview(
              imageBytes: widget.imageBytes,
              region: _regionFor(sign),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── 既定: 言語の多選＋任意の備考 ──
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.stdLangPrompt, style: AppText.sectionTitle()),
                const SizedBox(height: AppSpacing.sm),
                _chipMulti(t, sign, '主要言語', _langOptions),
                const SizedBox(height: AppSpacing.sm),
                _chipMulti(t, sign, '補助言語', _langOptions),
                const SizedBox(height: AppSpacing.sm),
                _noteField(t, sign),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── 展開: 少数の官方字段（完全表単は研究モードのみ） ──
          if (!_more)
            LLSecondaryButton(
              label: t.stdMoreInfo,
              icon: Icons.expand_more,
              onPressed: () => setState(() => _more = true),
            )
          else
            LLCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 展開字段は kStandardMoreFields（正準キー）で駆動する。
                  for (final f in kStandardMoreFields) ...[
                    if (widget.schema.multiFields.contains(f))
                      _chipMulti(t, sign, f, widget.schema.enums[f] ?? const [])
                    else
                      _dropdown(t, sign, f),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LLPrimaryButton(
            label: _isLast ? t.saveDone : t.saveNext,
            icon: _isLast ? Icons.check : Icons.arrow_forward,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  /// 複数選択チップ（値は既存慣習どおり「/」区切りで保存）。
  Widget _chipMulti(
      AppLocalizations t, Sign sign, String field, List<String> options) {
    final selected = splitMulti(sign.get(field));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_labelFor(t, field),
            style: AppText.caption().copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                visualDensity: VisualDensity.compact,
                selectedColor:
                    AppColors.accentTerracotta.withValues(alpha: 0.18),
                checkmarkColor: AppColors.accentTerracotta,
                onSelected: (_) {
                  setState(() {
                    final next = [...selected];
                    if (next.contains(o)) {
                      next.remove(o);
                    } else {
                      next.add(o);
                    }
                    sign.set(field, next.join('/'));
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown(AppLocalizations t, Sign sign, String field) {
    final options = widget.schema.enums[field] ?? const <String>[];
    final value = sign.get(field);
    final items = [...options];
    if (value.isNotEmpty && !items.contains(value)) items.insert(0, value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _labelFor(t, field),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => setState(() => sign.set(field, v ?? '')),
      ),
    );
  }

  Widget _noteField(AppLocalizations t, Sign sign) => TextFormField(
        key: ValueKey('${sign.id}-備考-std'),
        initialValue: sign.get('備考'),
        decoration: InputDecoration(
          labelText: _labelFor(t, '備考'),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => sign.set('備考', v),
      );
}
