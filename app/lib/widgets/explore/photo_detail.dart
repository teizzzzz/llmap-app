/// 照片详情（探索・地図・我的で共通）。
/// 探索からは全画面ページ（[PhotoDetailScreen]）、地図では抽屉の中身として
/// 同じ [PhotoDetailView] を使い、言語・地点・記録情報の見せ方を揃える。
library;

import 'package:flutter/material.dart';

import '../../explore/lang_codes.dart';
import '../../explore/photo_item.dart';
import '../../field_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../models.dart';
import '../../theme/tokens.dart';
import '../ll/ll.dart';
import 'photo_tile.dart';

class PhotoDetailView extends StatelessWidget {
  final PhotoItem item;
  final AppSchema schema;
  final ScrollController? controller;

  /// 先頭に差し込む行（地図抽屉のハンドル・「返回列表」など）。
  final Widget? header;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onEdit;
  final double maxImageHeight;

  /// 末尾に置く区画（「接下来探索」の関連カードなど）。
  final Widget? footer;

  const PhotoDetailView({
    super.key,
    required this.item,
    required this.schema,
    this.controller,
    this.header,
    this.onShowOnMap,
    this.onEdit,
    this.maxImageHeight = 420,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final img = item.image;
    return ListView(
      controller: controller,
      padding: EdgeInsets.zero,
      children: [
        ?header,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxImageHeight),
              child: ColoredBox(
                color: item.placeholder.withValues(alpha: 0.45),
                child: img == null
                    ? const SizedBox(
                        height: 200,
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Image(
                        image: img,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: AppText.sectionTitle(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LLTagChip(
                label: item.mine ? t.sourceMine : t.sourceShared,
                color: item.mine ? AppColors.primary : AppColors.link,
              ),
            ],
          ),
        ),
        if (item.langs.isNotEmpty || item.auxLangs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in item.langs)
                  LangChip(
                    label: langDisplayName(t, c),
                    color: langColor(schema, c),
                  ),
                for (final c in item.auxLangs.where(
                  (c) => !item.langs.contains(c),
                ))
                  LangChip(
                    label: langDisplayName(t, c),
                    color: langColor(schema, c),
                    strong: false,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            children: [
              if (item.time.isNotEmpty)
                _metaRow(Icons.schedule, t.capturedAt, item.time),
              _metaRow(
                Icons.place_outlined,
                t.locationLabel,
                item.hasLocation
                    ? '${item.lat!.toStringAsFixed(5)}, ${item.lng!.toStringAsFixed(5)}'
                    : t.noLocation,
              ),
            ],
          ),
        ),
        if (onShowOnMap != null || onEdit != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: LLPrimaryButton(
                      label: t.editRecord,
                      icon: Icons.edit_note,
                      onPressed: onEdit,
                    ),
                  ),
                if (onEdit != null && onShowOnMap != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onShowOnMap != null)
                  Expanded(
                    child: LLSecondaryButton(
                      label: t.showOnMap,
                      icon: Icons.map_outlined,
                      onPressed: item.hasLocation ? onShowOnMap : null,
                    ),
                  ),
              ],
            ),
          ),
        if (item.facts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: LLCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final (k, v) in item.facts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              fieldLabel(t, k),
                              style: AppText.caption(),
                            ),
                          ),
                          Expanded(child: Text(v, style: AppText.body())),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (item.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              item.note,
              style: AppText.body().copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ?footer,
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _metaRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: AppText.caption()),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: AppText.body().copyWith(fontSize: 13.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// 探索・我的から開く全画面の详情。戻ると元の一覧の位置・筛选のまま。
class PhotoDetailScreen extends StatelessWidget {
  final PhotoItem item;
  final AppSchema schema;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onEdit;
  final Widget? footer;

  const PhotoDetailScreen({
    super.key,
    required this.item,
    required this.schema,
    this.onShowOnMap,
    this.onEdit,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(item.label, style: AppText.sectionTitle()),
      ),
      body: PhotoDetailView(
        item: item,
        schema: schema,
        onShowOnMap: onShowOnMap,
        onEdit: onEdit,
        footer: footer,
        maxImageHeight: MediaQuery.of(context).size.height * 0.62,
      ),
    );
  }
}
