/// 地図上に浮かぶアプリヘッダ（タイトルピル＋左右アイコン）。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'll_buttons.dart';

class LLAppHeader extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final VoidCallback? onLeading;
  final IconData? trailingIcon;
  final VoidCallback? onTrailing;
  const LLAppHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.onLeading,
    this.trailingIcon,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        leadingIcon == null
            ? const SizedBox(width: 46)
            : LLIconButton(icon: leadingIcon!, onPressed: onLeading),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceIvory,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.floating,
          ),
          child: Text(title, style: AppText.appTitle()),
        ),
        trailingIcon == null
            ? const SizedBox(width: 46)
            : LLIconButton(icon: trailingIcon!, onPressed: onTrailing),
      ],
    );
  }
}
