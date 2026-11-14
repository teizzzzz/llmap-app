/// 「我的」：自分の採集を写真で振り返る（探索ページの Tab の 1 つ。頭像なし、写真が主役）。
/// 上に件数と「更多」（相册と一括管理・データ書き出し・地区コード）。設定は
/// 探索ページ右上の歯車から。
/// 写真の左上タグで記録の状態（待补充 / 已提交 / 已审核…）を区別する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../explore/photo_item.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/explore/photo_tile.dart';

class MyRecordsTab extends StatelessWidget {
  final AppSchema schema;
  final List<PhotoItem> items; // 新しい順
  final void Function(PhotoItem) onOpen;
  final VoidCallback onManage;
  final VoidCallback onExport;
  final VoidCallback onEditArea;
  final String areaLabel;

  const MyRecordsTab({
    super.key,
    required this.schema,
    required this.items,
    required this.onOpen,
    required this.onManage,
    required this.onExport,
    required this.onEditArea,
    required this.areaLabel,
  });

  /// DataStatus → 写真上の短い状態タグ。
  static String? statusTag(AppLocalizations t, String dataStatus) =>
      switch (dataStatus) {
        'raw' => t.statusRawTag,
        'submitted' => t.statusSubmittedTag,
        'ai_drafted' => t.statusAi,
        'reviewed' => t.statusHumanReviewed,
        'verified' => t.statusFinal,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CustomScrollView(
      key: const PageStorageKey('my-records'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Text(t.photosCount(items.length), style: AppText.caption()),
                const Spacer(),
                // 相册・一括操作と書き出しは、隠さずに常に見えるボタンで出す。
                _PillButton(
                  icon: Icons.photo_album_outlined,
                  label: t.manageShort,
                  onTap: items.isEmpty ? null : onManage,
                ),
                const SizedBox(width: AppSpacing.sm),
                _PillButton(
                  icon: Icons.ios_share,
                  label: t.exportData,
                  filled: true,
                  onTap: items.isEmpty ? null : onExport,
                ),
                PopupMenuButton<String>(
                  tooltip: t.moreActions,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (_) => onEditArea(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'area',
                      child: Text('${t.areaCodeTooltip} · $areaLabel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(t.emptyTitle, style: AppText.sectionTitle()),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    t.emptyBody,
                    textAlign: TextAlign.center,
                    style: AppText.body().copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childCount: items.length,
              itemBuilder: (_, i) => PhotoTile(
                key: ValueKey(items[i].key),
                item: items[i],
                schema: schema,
                badge: statusTag(t, items[i].dataStatus),
                onTap: () => onOpen(items[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// 小さな胶囊ボタン（白＋淡い縁 / 黒）。我的の見出し行の操作用。
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled ? Colors.white : AppColors.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: filled ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.borderSubtle),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppText.caption().copyWith(
                    fontSize: 12.5,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
