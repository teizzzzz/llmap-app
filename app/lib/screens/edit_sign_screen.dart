import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../store.dart';
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import '../widgets/sign_form.dart';

/// 既存 sign の編集／削除。フォームはウィザードと共用。
/// 戻り値: 'saved' 保存 / 'deleted' 削除 / null キャンセル。
class EditSignScreen extends StatefulWidget {
  final Sign sign;
  final AppSchema schema;
  const EditSignScreen({super.key, required this.sign, required this.schema});

  @override
  State<EditSignScreen> createState() => _EditSignScreenState();
}

class _EditSignScreenState extends State<EditSignScreen> {
  Future<void> _confirmDelete() async {
    final t = AppLocalizations.of(context);
    final ok = await showLLDialog<bool>(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.danger,
      title: t.deleteRecordTitle,
      message: t.deleteRecordConfirmIrreversible(widget.sign.displayId),
      primaryLabel: t.delete,
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: t.cancel,
      onSecondary: () => Navigator.pop(context, false),
    );
    if (ok == true && mounted) Navigator.pop(context, 'deleted');
  }

  /// 編集中の写真プレビュー。タップで全画面ズーム表示。
  Widget _preview() {
    final name = widget.sign.fileName;
    final file = name.isEmpty ? null : LocalStore.instance.photoFile(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: (file != null && file.existsSync())
            ? GestureDetector(
                onTap: () => _openFullImage(file),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover, gaplessPlayback: true),
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.zoom_out_map,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              )
            : ColoredBox(
                color: AppColors.muted,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary, size: 40),
                ),
              ),
      ),
    );
  }

  void _openFullImage(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(widget.sign.displayId),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  /// 識別情報カード（詳情表示）。短いラベルを見出しに、展開で全システム字段を出す。
  /// 字段キーは研究用の正準名のためそのまま表示する（i18n 対象外）。
  Widget _identityCard() {
    final s = widget.sign;
    final rows = <(String, String)>[
      ('SignID', s.id),
      ('CaptureID', s.captureId),
      ('DisplayID', s.displayId),
      ('写真ファイル名', s.fileName),
      ('元写真ファイル名', s.sourceFileName),
      ('採集者ID', s.collectorId),
      ('地区コード', s.get('地区コード')),
      ('採集日時', s.get('採集日時')),
      ('緯度', s.get('緯度')),
      ('経度', s.get('経度')),
      ('EntryMode', s.get('EntryMode')),
      ('DataStatus', s.get('DataStatus')),
      ('SchemaVersion', s.get('SchemaVersion')),
      ('AppVersion', s.get('AppVersion')),
    ].where((e) => e.$2.isNotEmpty).toList();
    return LLCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 2, 0, AppSpacing.md + 2, AppSpacing.md),
          title: Text(s.shortLabel,
              style: AppText.body()
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
          subtitle: Text(s.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption()),
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(r.$1, style: AppText.caption()),
                    ),
                    Expanded(
                      child: SelectableText(r.$2,
                          style: AppText.body().copyWith(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editTitle),
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
            tooltip: t.delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _preview(),
          const SizedBox(height: AppSpacing.md),
          _identityCard(),
          const SizedBox(height: AppSpacing.md),
          SignForm(
            sign: widget.sign,
            schema: widget.schema,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LLPrimaryButton(
            label: t.saveChanges,
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, 'saved'),
          ),
        ),
      ),
    );
  }
}
