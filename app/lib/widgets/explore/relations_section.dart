/// 照片详情の下に置く「接下来探索什么？」：関連 6 種をカードの横並びで出す。
/// カードを開くとその関連の写真一覧（瀑布流）へ。
library;

import 'package:flutter/material.dart';

import '../../explore/lang_codes.dart';
import '../../explore/photo_item.dart';
import '../../explore/relations.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

IconData relIcon(RelKind k) => switch (k) {
  RelKind.color => Icons.palette_outlined,
  RelKind.scene => Icons.crop_free,
  RelKind.near => Icons.place_outlined,
  RelKind.lang => Icons.translate,
  RelKind.type => Icons.sell_outlined,
  RelKind.contrast => Icons.contrast,
};

String relName(AppLocalizations t, RelKind k) => switch (k) {
  RelKind.color => t.relColorName,
  RelKind.scene => t.relSceneName,
  RelKind.near => t.relNearName,
  RelKind.lang => t.relLangName,
  RelKind.type => t.relTypeName,
  RelKind.contrast => t.relContrastName,
};

String relTitle(AppLocalizations t, Relation r) => switch (r.kind) {
  RelKind.color => t.relColorName,
  RelKind.scene => t.relSceneName,
  RelKind.near => t.relNearName,
  RelKind.lang => t.relLangTitle(
    r.langs.isEmpty
        ? t.langNone
        : r.langs.map((c) => langDisplayName(t, c)).join(' · '),
  ),
  RelKind.type => '${r.discourse.replaceAll('话语', '')} · ${r.carrier}',
  RelKind.contrast => t.relContrastName,
};

String relSubtitle(AppLocalizations t, Relation r) => switch (r.kind) {
  RelKind.color => t.relColorSub(r.items.length),
  RelKind.scene => t.relSceneSub(r.items.length),
  RelKind.near => t.relNearSub(r.radiusM, r.items.length),
  RelKind.lang => t.relLangSub(r.items.length),
  RelKind.type => t.relTypeSub(r.items.length),
  RelKind.contrast => t.relContrastSub(langDisplayName(t, r.mainLang)),
};

class RelationsSection extends StatelessWidget {
  final List<Relation> relations;
  final List<PhotoItem> shared; // 探索データの写真（index で引く）
  final void Function(Relation r) onOpen;

  const RelationsSection({
    super.key,
    required this.relations,
    required this.shared,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(t.exploreNext, style: AppText.sectionTitle()),
        ),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: relations.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) => _card(t, relations[i]),
          ),
        ),
      ],
    );
  }

  Widget _card(AppLocalizations t, Relation r) {
    final cover = shared[r.items.first];
    final stack = r.items.skip(1).take(3).map((j) => shared[j]).toList();
    return GestureDetector(
      onTap: () => onOpen(r),
      child: SizedBox(
        width: 168,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: cover.placeholder),
              if (cover.image != null)
                Image(
                  image: ResizeImage(
                    cover.image!,
                    width: 400,
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xC0000000)],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        relIcon(r.kind),
                        size: 13,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        relName(t, r.kind),
                        style: AppText.caption().copyWith(
                          fontSize: 10.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    for (final p in stack)
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          color: p.placeholder,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                          image: p.image == null
                              ? null
                              : DecorationImage(
                                  image: ResizeImage(p.image!, width: 80),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relTitle(t, r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body().copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      relSubtitle(t, r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption().copyWith(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
