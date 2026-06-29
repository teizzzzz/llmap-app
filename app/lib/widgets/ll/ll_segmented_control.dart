/// セグメント切替（Map / Satellite など）。design tokens 参照。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class LLSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const LLSegment(this.value, this.label, {this.icon});
}

class LLSegmentedControl<T> extends StatelessWidget {
  final List<LLSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color activeColor;
  final Color activeTextColor;
  const LLSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.activeColor = AppColors.accentMustard,
    this.activeTextColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceIvory,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            GestureDetector(
              onTap: () => onChanged(s.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: s.value == selected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.icon != null) ...[
                      Icon(s.icon,
                          size: 16,
                          color: s.value == selected
                              ? activeTextColor
                              : AppColors.textSecondary),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      s.label,
                      style: AppText.button().copyWith(
                        fontSize: 14,
                        color: s.value == selected
                            ? activeTextColor
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
