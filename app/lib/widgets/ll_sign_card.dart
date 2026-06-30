/// 採集記録の1枚カード（記録パネル/一覧で共用）。design tokens 参照。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart' show statusBadge;
import '../theme/tokens.dart';

class LLSignCard extends StatelessWidget {
  final Sign sign;
  final int index;
  final VoidCallback onTap;
  const LLSignCard(
      {super.key, required this.sign, required this.index, required this.onTap});

  /// 先頭のサムネイル（46×46）。写真が無ければ番号ボックスにフォールバック。
  /// 写真がある場合も番号を小バッジで重ねて並び順を保持。
  Widget _thumb() {
    final name = sign.fileName;
    final file = name.isEmpty ? null : LocalStore.instance.photoFile(name);
    final radius = BorderRadius.circular(AppRadius.md);
    final numberBox = Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: radius),
      child: Text('${index + 1}',
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    );
    if (file == null || !file.existsSync()) return numberBox;
    return SizedBox(
      width: 46,
      height: 46,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover, gaplessPlayback: true,
                errorBuilder: (_, _, _) => numberBox),
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6)),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              _thumb(),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign.name.isEmpty
                          ? AppLocalizations.of(context).untitled
                          : sign.name,
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
