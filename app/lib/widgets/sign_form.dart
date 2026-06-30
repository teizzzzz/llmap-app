/// sign の字段編集フォーム（schema.enums から自動生成）。
/// 撮影フローのウィザードと、既存データの編集画面で共用する。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../theme/tokens.dart';

class SignForm extends StatelessWidget {
  final Sign sign;
  final AppSchema schema;
  final VoidCallback onChanged;
  const SignForm({
    super.key,
    required this.sign,
    required this.schema,
    required this.onChanged,
  });

  // 人が編集したら human-reviewed に昇格（AI下書を人が校閲した＝研究主体性の証跡）。
  // final（確定済）は人の編集でも保持する。
  void _markEdited() {
    if (sign.status == 'pending' || sign.status == 'ai') {
      sign.set('_status', 'human-reviewed');
    }
  }

  void _onEdited() {
    _markEdited();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(sign.id,
                  style: AppText.body().copyWith(fontWeight: FontWeight.w800)),
            ),
            statusBadge(sign.status),
          ],
        ),
        Text(
            t.signMeta(
              '${sign.lat ?? '—'}',
              '${sign.lng ?? '—'}',
              sign.get('採集日時').isEmpty ? '—' : sign.get('採集日時'),
            ),
            style: AppText.caption()),
        const Divider(),
        for (final field in schema.editableFields) _fieldEditor(field),
      ],
    );
  }

  Widget _fieldEditor(String field) {
    // 複数選択かつ自由追加できる字段（言語3つ・文字体系）。
    if (schema.multiFields.contains(field)) {
      return _MultiSelectField(
        key: ValueKey('${sign.id}-$field-multi'),
        label: field,
        options: schema.enums[field] ?? const [],
        value: sign.get(field),
        onChanged: (v) {
          sign.set(field, v);
          _onEdited();
        },
      );
    }

    final options = schema.enums[field];
    final value = sign.get(field);
    if (options != null) {
      final items = [...options];
      if (value.isNotEmpty && !items.contains(value)) items.insert(0, value);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: items
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            sign.set(field, v ?? '');
            _onEdited();
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${sign.id}-$field'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: field,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          sign.set(field, v);
          _markEdited();
        },
      ),
    );
  }
}

/// 複数選択 ＋ 自由追加できる字段エディタ。
/// プリセット選択肢はチップで切替、選択肢に無い値は入力欄から追加できる。
/// 値は「/」区切りの文字列で保存する（例「日本語/韓国語」）。
class _MultiSelectField extends StatefulWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _MultiSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MultiSelectField> createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<_MultiSelectField> {
  late final List<String> _selected = splitMulti(widget.value);
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _commit() => widget.onChanged(_selected.join('/'));

  void _toggle(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
    _commit();
  }

  void _addCustom() {
    final v = _custom.text.trim();
    if (v.isEmpty || _selected.contains(v)) {
      _custom.clear();
      return;
    }
    setState(() => _selected.add(v));
    _custom.clear();
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    // 選択肢に無い、自由追加された選択値。
    final extras =
        _selected.where((v) => !widget.options.contains(v)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: AppText.caption()
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final o in widget.options)
                FilterChip(
                  label: Text(o),
                  selected: _selected.contains(o),
                  onSelected: (_) => _toggle(o),
                  visualDensity: VisualDensity.compact,
                  selectedColor: AppColors.accentTerracotta.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.accentTerracotta,
                ),
              // 自由追加した値は削除可能なチップで表示。
              for (final e in extras)
                InputChip(
                  label: Text(e),
                  selected: true,
                  onDeleted: () => _toggle(e),
                  visualDensity: VisualDensity.compact,
                  selectedColor: AppColors.accentBlue.withValues(alpha: 0.18),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '+ 自定义 / カスタム追加',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '追加',
                onPressed: _addCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 状態バッジは theme.dart の statusBadge() を共用する。
