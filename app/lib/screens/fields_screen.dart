import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../settings.dart';
import '../widgets/crop_preview.dart';
import '../widgets/sign_form.dart';

/// 字段入力ウィザード（⑥）。框选した sign を1つずつ入力する。
/// 上=框选プレビュー、下=入力。各 sign で skip / 保存 を選び次へ。
/// AI が有効なら各 sign に入った時点で自動識別する。
class FieldsScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  final Uint8List imageBytes;
  final String fileName;
  final List<Sign> signs;
  final List<CropRegion> regions;
  final AiConfig aiConfig;

  const FieldsScreen({
    super.key,
    required this.api,
    required this.schema,
    required this.imageBytes,
    required this.fileName,
    required this.signs,
    required this.regions,
    required this.aiConfig,
  });

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  int _index = 0;
  bool _aiBusy = false;
  final List<Sign> _saved = [];
  final Set<int> _aiDone = {};

  @override
  void initState() {
    super.initState();
    _maybeAutoAi();
  }

  Sign get _current => widget.signs[_index];
  bool get _isLast => _index >= widget.signs.length - 1;

  CropRegion? _regionFor(Sign sign) {
    final suffix = sign.id.split('-').last; // AREA-SNNN-suffix
    for (final r in widget.regions) {
      if (r.suffix == suffix) return r;
    }
    return null;
  }

  Future<void> _maybeAutoAi() async {
    if (!widget.aiConfig.enabled) return;
    if (_aiDone.contains(_index)) return;
    _aiDone.add(_index);
    await _runAi(_current);
  }

  Future<void> _runAi(Sign sign) async {
    setState(() => _aiBusy = true);
    try {
      final fields = await widget.api.ai(
        photoBytes: widget.imageBytes,
        fileName: widget.fileName,
        provider: widget.aiConfig.provider,
        fields: widget.schema.aiFields,
        crop: _regionFor(sign),
        apiKey: widget.aiConfig.apiKey,
      );
      if (!mounted) return;
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

  void _advance() {
    if (_isLast) {
      Navigator.pop(context, _saved);
    } else {
      setState(() => _index++);
      _maybeAutoAi();
    }
  }

  void _skip() => _advance();

  void _save() {
    if (_current.status == 'pending') _current.set('_status', 'modified');
    _saved.add(_current);
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.signs.length;
    final sign = _current;
    final suffix = sign.id.split('-').last;
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
        actions: [
          if (widget.aiConfig.enabled)
            IconButton(
              tooltip: 'AI再識別',
              onPressed: _aiBusy ? null : () => _runAi(sign),
              icon: const Icon(Icons.auto_awesome),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            // sign が変わるたびにフォーム(controller)を作り直す
            key: ValueKey(sign.id),
            padding: const EdgeInsets.all(12),
            children: [
              // 上: 框选プレビュー
              CropPreview(
                imageBytes: widget.imageBytes,
                region: _regionFor(sign),
              ),
              const SizedBox(height: 12),
              // 下: 入力
              SignForm(
                sign: sign,
                schema: widget.schema,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 80),
            ],
          ),
          if (_aiBusy)
            const Positioned(
              top: 8,
              right: 8,
              child: Chip(
                avatar: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text('AI識別中…'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _aiBusy ? null : _skip,
                icon: const Icon(Icons.skip_next),
                label: const Text('スキップ'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _aiBusy ? null : _save,
                  icon: Icon(_isLast ? Icons.check : Icons.arrow_forward),
                  label: Text(_isLast
                      ? '保存して地図へ'
                      : '保存して次へ（${_index + 2}/$total）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
