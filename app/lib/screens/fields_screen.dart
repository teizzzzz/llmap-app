import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai.dart' as ai;
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../settings.dart';
import '../store.dart';
import '../theme/tokens.dart';
import '../widgets/crop_preview.dart';
import '../widgets/ll/ll.dart';
import '../widgets/sign_form.dart';

/// 字段入力ウィザード（⑥）。框选した sign を1つずつ入力する。
/// 上=框选プレビュー、下=入力。各 sign で skip / 保存 を選び次へ。
/// AI が有効なら各 sign に入った時点で自動識別する。
class FieldsScreen extends StatefulWidget {
  final AppSchema schema;
  final Uint8List imageBytes;
  final List<Sign> signs;
  final List<CropRegion> regions;
  final AiConfig aiConfig;

  const FieldsScreen({
    super.key,
    required this.schema,
    required this.imageBytes,
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
    final suffix = sign.cropSuffix; // 新: CropSuffix 字段 / 旧: SignID 末尾
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
      // 端末に保存済みの裁切写真を読み、無ければ全景にフォールバック。
      final name = sign.get('写真ファイル名');
      final f = LocalStore.instance.photoFile(name);
      final bytes =
          await f.exists() ? await f.readAsBytes() : widget.imageBytes;
      final fields = await ai.judge(
        photoBytes: bytes,
        provider: widget.aiConfig.provider,
        fields: widget.schema.aiFields,
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).aiFailed('$e'))));
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

  /// 暂存: AI識別も手動入力もせず、そのまま入库（status は pending のまま）。
  /// 後で一括AI識別/修正するための「とりあえず保存」。
  void _skip() {
    _saved.add(_current);
    _advance();
  }

  /// 入力済みとして保存（pending/ai なら human-reviewed に昇格）。
  void _save() {
    if (_current.status == 'pending' || _current.status == 'ai') {
      _current.set('_status', 'human-reviewed');
    }
    _saved.add(_current);
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final total = widget.signs.length;
    final sign = _current;
    final suffix = sign.cropSuffix;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.fieldsTitle(suffix, _index + 1, total)),
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
        actions: [
          if (widget.aiConfig.enabled)
            IconButton(
              tooltip: t.reRecognize,
              onPressed: _aiBusy ? null : () => _runAi(sign),
              icon: const Icon(Icons.auto_awesome),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
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
              SignForm(
                sign: sign,
                schema: widget.schema,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 80),
            ],
          ),
          if (_aiBusy)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: LLTagChip(
                  label: t.recognizing,
                  color: AppColors.accentBlue,
                  icon: Icons.auto_awesome),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 暂存 = 不填写直接入库（之后可批量 AI/修正）。主ボタン。
              LLPrimaryButton(
                label: _isLast ? t.stashDone : t.stashNext,
                icon: _isLast ? Icons.check : Icons.skip_next,
                onPressed: _aiBusy ? null : _skip,
              ),
              const SizedBox(height: AppSpacing.sm),
              // 填写后保存（modified）。副ボタン。
              LLSecondaryButton(
                label: _isLast ? t.saveDone : t.saveNext,
                icon: Icons.save_outlined,
                onPressed: _aiBusy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
