/// 採集記録の1枚カード（記録パネル/一覧で共用）。design tokens 参照。
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart' show statusBadge;
import '../theme/tokens.dart';

class LLSignCard extends StatelessWidget {
  final Sign sign;
  final int index;
  final VoidCallback onTap;
  const LLSignCard(
      {super.key, required this.sign, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasGps = sign.lat != null && sign.lng != null;
    return Material(
      color: AppColors.surfaceIvory,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign.name.isEmpty ? '(未填写名称)' : sign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body()
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(hasGps ? Icons.place : Icons.location_off,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${sign.id}'
                            '${sign.mainLang.isEmpty ? '' : ' · ${sign.mainLang}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              statusBadge(sign.status),
            ],
          ),
        ),
      ),
    );
  }
}
