/// 角丸ダイアログ（アイコン＋タイトル＋本文＋ボタン）。design tokens 参照。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'll_buttons.dart';

/// 汎用ダイアログ。primaryLabel で主ボタン、secondaryLabel で副ボタン。
Future<T?> showLLDialog<T>(
  BuildContext context, {
  IconData? icon,
  Color? iconColor,
  required String title,
  String? message,
  required String primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surfaceIvory,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.accentMustard)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon,
                    size: 36, color: iconColor ?? AppColors.accentTerracotta),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(title, textAlign: TextAlign.center, style: AppText.sectionTitle()),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: AppText.body().copyWith(
                      color: AppColors.textSecondary, height: 1.45)),
            ],
            const SizedBox(height: AppSpacing.xl),
            LLPrimaryButton(
              label: primaryLabel,
              onPressed: onPrimary ?? () => Navigator.pop(ctx),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              LLSecondaryButton(
                label: secondaryLabel,
                onPressed: onSecondary ?? () => Navigator.pop(ctx),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
