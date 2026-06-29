/// 共通ボタン部品（design tokens 参照・業務ロジックなし）。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 主アクション（テラコッタ橙のピル）。busy でスピナー表示。
class LLPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  final Color? color;
  final Color? foreground;
  const LLPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.expand = true,
    this.color,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.surfaceIvory;
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.accentTerracotta,
          foregroundColor: fg,
          disabledBackgroundColor:
              (color ?? AppColors.accentTerracotta).withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          textStyle: AppText.button(),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// 副アクション（アウトライン）。
class LLSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  const LLSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          textStyle: AppText.button().copyWith(fontSize: 15),
        ),
      ),
    );
  }
}

/// 円形アイコンボタン（地図上などの浮きボタン）。
class LLIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? background;
  final Color? iconColor;
  const LLIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 46,
    this.background,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceIvory,
        shape: BoxShape.circle,
        boxShadow: AppShadows.floating,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon,
              size: size * 0.46, color: iconColor ?? AppColors.textPrimary),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
