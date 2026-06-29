/// 進捗ダイアログ（導出など長時間処理用）。design tokens 参照。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class LLProgressDialog extends StatelessWidget {
  final String title;
  final String? unit; // 例: '张照片'
  final ValueListenable<({int done, int total})> progress;
  const LLProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceIvory,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionTitle()),
            const SizedBox(height: AppSpacing.lg),
            ValueListenableBuilder<({int done, int total})>(
              valueListenable: progress,
              builder: (context, p, _) {
                final finished = p.total > 0 && p.done >= p.total;
                final value = finished ? 1.0 : (p.total > 0 ? p.done / p.total : null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.muted,
                        color: finished
                            ? AppColors.success
                            : AppColors.accentTerracotta,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (finished)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle,
                                size: 15, color: AppColors.success),
                          ),
                        Text(
                          finished
                              ? '完成 · 共 ${p.total}${unit ?? ''}'
                              : p.total > 0
                                  ? '${p.done} / ${p.total}${unit ?? ''}'
                                  : '处理中…',
                          style: AppText.caption().copyWith(
                              color: finished
                                  ? AppColors.success
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
