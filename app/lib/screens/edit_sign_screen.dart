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
      message: t.deleteRecordConfirmIrreversible(widget.sign.id),
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
            title: Text(widget.sign.id),
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
