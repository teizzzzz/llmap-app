import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

/// 字段入力画面（⑥手動／AI）。schema.enums からフォームを自動生成。
class FieldsScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  final Uint8List imageBytes;
  final String fileName;
  final List<Sign> signs;
  final List<CropRegion> regions;

  const FieldsScreen({
    super.key,
    required this.api,
    required this.schema,
    required this.imageBytes,
    required this.fileName,
    required this.signs,
    required this.regions,
  });

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  bool _aiBusy = false;
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= widget.signs.length - 1;

  void _goNext() {
    if (_isLast) {
      _save();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _goPrev() {
    if (_index > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  CropRegion? _regionFor(Sign sign) {
    final suffix = sign.id.split('-').last; // AREA-SNNN-suffix
    for (final r in widget.regions) {
      if (r.suffix == suffix) return r;
    }
    return null;
  }

  Future<void> _runAi(Sign sign) async {
    setState(() => _aiBusy = true);
    try {
      // 框选ごとに全景から切り出して判定（sign単位で正確に）。
      final fields = await widget.api.ai(
        photoBytes: widget.imageBytes,
        fileName: widget.fileName,
        provider: 'claude',
        fields: widget.schema.aiFields,
        crop: _regionFor(sign),
      );
      setState(() {
        fields.forEach((k, v) {
          if (v != null && v.toString().isNotEmpty) sign.set(k, v.toString());
        });
        sign.set('_status', 'ai');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI识别失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _save() {
    for (final s in widget.signs) {
      if (s.status == 'pending') s.set('_status', 'modified');
    }
    Navigator.pop(context, widget.signs);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.signs.length;
    final current = widget.signs[_index];
    final suffix = current.id.split('-').last;
    return Scaffold(
      appBar: AppBar(
        title: Text('字段入力  $suffix  (${_index + 1}/$total)'),
        bottom: total > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / total,
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final sign = widget.signs[i];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _SignCard(
              sign: sign,
              schema: widget.schema,
              aiBusy: _aiBusy,
              onAi: () => _runAi(sign),
              onApprove: () =>
                  setState(() => sign.set('_status', 'reviewed')),
              onChanged: () => setState(() {}),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_index > 0)
                OutlinedButton.icon(
                  onPressed: _goPrev,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('前へ'),
                ),
              if (_index > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goNext,
                  icon: Icon(_isLast ? Icons.check : Icons.arrow_forward),
                  label: Text(_isLast
                      ? '保存して地図へ'
                      : '次の景観へ（${_index + 2}/$total）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  final Sign sign;
  final AppSchema schema;
  final bool aiBusy;
  final VoidCallback onAi;
  final VoidCallback onApprove;
  final VoidCallback onChanged;

  const _SignCard({
    required this.sign,
    required this.schema,
    required this.aiBusy,
    required this.onAi,
    required this.onApprove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sign.id,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                _statusBadge(sign.status),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: aiBusy ? null : onAi,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI识别'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed:
                      sign.status == 'reviewed' ? null : onApprove,
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('承認'),
                ),
              ],
            ),
            Text('GPS: ${sign.lat ?? '—'}, ${sign.lng ?? '—'}  ·  '
                '採集: ${sign.get('採集日時').isEmpty ? '—' : sign.get('採集日時')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            for (final field in schema.editableFields)
              _fieldEditor(field),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = {
          'pending': Colors.grey,
          'ai': Colors.blue,
          'modified': Colors.orange,
          'reviewed': Colors.green,
        }[status] ??
        Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  // 編集が入ったら reviewed/ai から modified に落とす（AIが上書きしないよう分層）。
  void _markEdited() {
    if (sign.status == 'reviewed' || sign.status == 'ai') {
      sign.set('_status', 'modified');
    }
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
