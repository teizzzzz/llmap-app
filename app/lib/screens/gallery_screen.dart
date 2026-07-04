/// 采集档案（筛选型档案画廊）。采集記録を缩略图カード网格で閲覧し、
/// 言語・来源でフィルタ、タップで編集。HomeScreen が状態オーナーのまま、
/// 編集/削除は callback で委譲する（業務ロジックは複製しない）。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart' show statusBadge;
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import 'edit_sign_screen.dart';

class GalleryScreen extends StatefulWidget {
  final List<Sign> signs; // HomeScreen._signs の参照（共有）
  final AppSchema schema;
  final void Function(Sign sign) onDelete; // 削除を Home に委譲
  final VoidCallback onChanged; // 保存後の Home 再描画・永続化

  const GalleryScreen({
    super.key,
    required this.signs,
    required this.schema,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const _all = '全部';
  String _lang = _all;
  String _source = _all;

  // multi=true の字段（主要言語など）は "/" 区切りを個々の値に展開する。
  List<String> _distinct(String key, {bool multi = false}) {
    final set = <String>{};
    for (final s in widget.signs) {
      final v = s.get(key);
      if (v.isEmpty || v == '—') continue;
      if (multi) {
        set.addAll(splitMulti(v));
      } else {
        set.add(v);
      }
    }
    return [_all, ...set];
  }

  List<Sign> get _filtered => widget.signs.where((s) {
        final okLang =
            _lang == _all || splitMulti(s.get('主要言語')).contains(_lang);
        final okSrc = _source == _all || s.get('設置主体') == _source;
        return okLang && okSrc;
      }).toList();

  Future<void> _edit(Sign s) async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSignScreen(sign: s, schema: widget.schema),
      ),
    );
    if (!mounted) return;
    if (r == 'deleted') {
      widget.onDelete(s);
      setState(() {});
    } else if (r == 'saved') {
      widget.onChanged();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final langs = _distinct('主要言語', multi: true);
    final sources = _distinct('設置主体');
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.galleryTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _filterRow(t.langFilter, langs, _lang, true,
                  (v) => setState(() => _lang = v)),
              _filterRow(t.sourceFilter, sources, _source, false,
                  (v) => setState(() => _source = v)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Text(
                  widget.signs.isEmpty ? t.emptyTitle : t.noMatch,
                  style: AppText.body().copyWith(color: AppColors.textSecondary)),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 232,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _card(filtered[i]),
            ),
    );
  }

  Widget _filterRow(String label, List<String> options, String selected,
      bool colored, ValueChanged<String> onPick) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 36, child: Text(label, style: AppText.caption())),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Row(
                children: [
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _choiceChip(
                        o == _all ? AppLocalizations.of(context).all : o,
                        o == selected,
                        () => onPick(o),
                        dotColor: colored && o != _all
                            ? parseHexColor(
                                widget.schema.languageColors[o] ?? '#888888')
                            : null,
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

  Widget _choiceChip(String label, bool selected, VoidCallback onTap,
      {Color? dotColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTerracotta : AppColors.surfaceIvory,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected
                  ? AppColors.accentTerracotta
                  : AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: AppText.caption().copyWith(
                    color: selected
                        ? AppColors.surfaceIvory
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _card(Sign s) {
    final lang = s.get('主要言語');
    final source = s.get('設置主体');
    return LLCard(
      padding: EdgeInsets.zero,
      onTap: () => _edit(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图＋状態バッジ
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(s),
                Positioned(
                  top: 6,
                  right: 6,
                  child: statusBadge(s.status),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name.isEmpty ? AppLocalizations.of(context).untitled : s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body()
                          .copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(s.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption().copyWith(fontSize: 11)),
                  const Spacer(),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (lang.isNotEmpty && lang != '—')
                        _langTag(lang),
                      if (source.isNotEmpty && source != '—' && source != '不明')
                        _sourceTag(source),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(Sign s) {
    final name = s.fileName;
    if (name.isEmpty) return _thumbFallback();
    return Image.file(
      LocalStore.instance.photoFile(name),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _thumbFallback(),
    );
  }

  Widget _thumbFallback() => Container(
        color: AppColors.muted,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.textSecondary),
      );

  Widget _langTag(String lang) {
    // 多選/併記時は先頭言語で色を引く（表示は全体）。
    final parts = splitMulti(lang);
    final primary = parts.isEmpty ? lang : parts.first;
    final c = parseHexColor(widget.schema.languageColors[primary] ?? '#888888');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(lang,
              style: AppText.caption()
                  .copyWith(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sourceTag(String source) {
    // 来源は長いので先頭の主要語のみ表示（例 "top-down(標準化)" → "top-down"）。
    final short = source.split('(').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(short,
          style: AppText.caption().copyWith(fontSize: 11)),
    );
  }
}
