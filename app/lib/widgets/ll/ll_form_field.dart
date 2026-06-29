/// ラベル付きフォーム行のラッパ（design tokens 参照）。
/// 入力ウィジェット自体は子に渡す（業務ロジックは持たない）。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class LLFormField extends StatelessWidget {
  final String label;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  const LLFormField({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: iconColor ?? AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppText.caption()),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        child,
      ],
    );
  }
}
