/// sign の字段編集フォーム（schema.enums から自動生成）。
/// 撮影フローのウィザードと、既存データの編集画面で共用する。
library;

import 'package:flutter/material.dart';

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

  // 編集が入ったら reviewed/ai から modified に落とす（AIが現場判断を上書きしない分層）。
  void _markEdited() {
    if (sign.status == 'reviewed' || sign.status == 'ai') {
      sign.set('_status', 'modified');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        Text('GPS：${sign.lat ?? '—'}, ${sign.lng ?? '—'}  ·  '
            '采集：${sign.get('採集日時').isEmpty ? '—' : sign.get('採集日時')}',
            style: AppText.caption()),
        const Divider(),
        for (final field in schema.editableFields) _fieldEditor(field),
      ],
    );
  }

  Widget _fieldEditor(String field) {
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
            _markEdited();
            onChanged();
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

// 状態バッジは theme.dart の statusBadge() を共用する。
