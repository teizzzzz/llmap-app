/// ボトムシート（ハンドル＋タイトル＋項目）。design tokens 参照。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 汎用ボトムシートを表示。
Future<T?> showLLBottomSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => LLBottomSheetScaffold(title: title, children: children),
  );
}

class LLBottomSheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const LLBottomSheetScaffold(
      {super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceIvory,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
              child: Text(title, style: AppText.sectionTitle()),
            ),
            ...children,
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// シート内の1行（アイコン＋ラベル＋シェブロン）。
class LLSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;
  const LLSheetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(label,
                    style: AppText.body().copyWith(
                        color: c, fontWeight: FontWeight.w700)),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
