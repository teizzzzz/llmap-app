/// 言語別の色凡例カード。地図の隅に置く。
library;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme/tokens.dart';

class LLMapLegend extends StatelessWidget {
  final AppSchema schema;
  const LLMapLegend({super.key, required this.schema});

  @override
  Widget build(BuildContext context) {
    final entries = schema.languageColors.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceIvory.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                        color: parseHexColor(e.value), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(e.key, style: AppText.caption().copyWith(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
