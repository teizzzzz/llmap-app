/// 角丸アイボリーカード（design tokens 参照）。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class LLCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool shadow;
  const LLCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.radius = AppRadius.lg,
    this.color,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceIvory,
        borderRadius: r,
        boxShadow: shadow ? AppShadows.card : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// 小さなタグ/チップ（汎用）。状態バッジは theme.dart の statusBadge を使う。
class LLTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const LLTagChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(label,
              style: AppText.caption().copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
