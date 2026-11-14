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
    final fg = foreground ?? AppColors.surface;
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          foregroundColor: fg,
          disabledBackgroundColor:
              (color ?? AppColors.primary).withValues(alpha: 0.28),
          disabledForegroundColor: fg.withValues(alpha: 0.9),
          elevation: 0,
          shape: const StadiumBorder(),
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
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderSubtle),
          shape: const StadiumBorder(),
          textStyle: AppText.button().copyWith(fontSize: 14.5),
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
        color: background ?? AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle),
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
