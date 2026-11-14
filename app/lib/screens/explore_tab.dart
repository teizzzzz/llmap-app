/// 探索タブ：写真から自由に発見する。
/// 上部の内容 Tab（图片流 / 主题 / 我的）はタップと左右スワイプで切替。
/// 右上の歯車から設定へ（3 つの Tab のどこからでも同じ位置）。
/// 言語・色・検索は「浏览工具」として图片流の上に置き、効いている条件は
/// チップで常に見せる。各 Tab は keepAlive で、详情から戻ってもスクロール位置・
/// 筛选条件がそのまま残る（地図・我的への切替でも IndexedStack で保持）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../explore/dataset.dart';
import '../explore/lang_codes.dart';
import '../explore/photo_item.dart';
import '../explore/themes.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../field_labels.dart';
import '../theme/tokens.dart';
import '../widgets/explore/photo_canvas.dart';
import '../widgets/explore/photo_tile.dart';
import '../widgets/ll/ll.dart';

/// 探索データの読込状態（HomeScreen が持ち、探索タブは表示だけ）。
enum ExploreLoad { none, loading, ready, failed }

class ExploreTab extends StatefulWidget {
  final AppSchema schema;
  final ExploreLoad load;
  final String? loadError;
  final ExploreDataset? dataset;

  /// 探索データの写真（records と同じ並び＝ index で引ける）。
  final List<PhotoItem> sharedItems;

  /// 端末の記録（探索データが無いときの代わり）。
  final List<PhotoItem> mineItems;
  final void Function(PhotoItem item) onOpen;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  /// 「我的」Tab の中身（自分の記録。HomeScreen が組み立てる）。
  final Widget mineView;

  const ExploreTab({
    super.key,
    required this.schema,
    required this.load,
    required this.loadError,
    required this.dataset,
    required this.sharedItems,
    required this.mineItems,
    required this.onOpen,
    required this.onOpenSettings,
    required this.onRetry,
    required this.mineView,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  // 漫游画布の表示中は、ドラッグを画布の移動に使う（Tab はタップでのみ切替）。
  bool _canvasOn = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorColor: AppColors.textPrimary,
                      indicatorWeight: 2.5,
                      labelPadding: const EdgeInsets.only(right: AppSpacing.xl),
                      labelStyle: AppText.sectionTitle().copyWith(fontSize: 20),
                      unselectedLabelStyle: AppText.sectionTitle().copyWith(
                        fontSize: 20,
                        color: AppColors.textSecondary,
                      ),
                      tabs: [
                        Tab(text: t.tabFeed),
                        Tab(text: t.tabThemes),
                        Tab(text: t.navMine),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.settings,
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: _canvasOn ? const NeverScrollableScrollPhysics() : null,
              children: [
                _FeedPage(
                  schema: widget.schema,
                  dataset: widget.dataset,
                  onCanvasChanged: (on) {
                    if (on != _canvasOn) setState(() => _canvasOn = on);
                  },
                  load: widget.load,
                  loadError: widget.loadError,
                  items: widget.dataset != null
                      ? widget.sharedItems
                      : widget.mineItems,
                  usingShared: widget.dataset != null,
                  onOpen: widget.onOpen,
                  onOpenSettings: widget.onOpenSettings,
                  onRetry: widget.onRetry,
                ),
                _ThemesPage(
                  schema: widget.schema,
                  dataset: widget.dataset,
                  sharedItems: widget.sharedItems,
                  load: widget.load,
                  onOpen: widget.onOpen,
                  onOpenSettings: widget.onOpenSettings,
                ),
                _KeepAlive(child: widget.mineView),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TabBarView の中で、離れても状態（スクロール位置）を保つ。
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ───────────────────────── 图片流 ─────────────────────────

class _FeedPage extends StatefulWidget {
  final AppSchema schema;
  final ExploreDataset? dataset;
  final ValueChanged<bool> onCanvasChanged;
  final ExploreLoad load;
  final String? loadError;
  final List<PhotoItem> items;
  final bool usingShared;
  final void Function(PhotoItem) onOpen;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  const _FeedPage({
    required this.schema,
    required this.dataset,
    required this.onCanvasChanged,
    required this.load,
    required this.loadError,
    required this.items,
    required this.usingShared,
    required this.onOpen,
    required this.onOpenSettings,
    required this.onRetry,
  });

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _langs = {};
  final Set<String> _colors = {};
  final _query = TextEditingController();
  bool _canvas = false; // 漫游画布で見る
  CanvasLayout _layout = CanvasLayout.wall;
  String _groupKey = 'cn';

  /// 画布は探索データ（atlas と事前計算の位置）があるときだけ使える。
  bool get _canvasAvailable =>
      widget.usingShared && widget.dataset?.atlasUrl != null;

  void _setCanvas(bool on) {
    setState(() => _canvas = on);
    widget.onCanvasChanged(on);
  }

  @override
  void didUpdateWidget(_FeedPage old) {
    super.didUpdateWidget(old);
    // 探索データが外れたら画布も閉じる（Tab のスワイプも戻す）。
    if (_canvas && !_canvasAvailable) {
      _canvas = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCanvasChanged(false),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static List<String> _langsOf(PhotoItem p) =>
      p.langs.isEmpty ? const ['none'] : p.langs;

  /// 新しい順に並べた全体（筛选前）。
  List<PhotoItem> get _ordered =>
      [...widget.items]..sort((a, b) => b.time.compareTo(a.time));

  List<PhotoItem> _apply(List<PhotoItem> all) {
    final q = _query.text.trim().toLowerCase();
    return all.where((p) {
      if (_langs.isNotEmpty && !_langsOf(p).any(_langs.contains)) {
        return false;
      }
      if (_colors.isNotEmpty && !_colors.contains(p.colorName)) return false;
      if (q.isNotEmpty &&
          !p.label.toLowerCase().contains(q) &&
          !p.note.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get _filtered =>
      _langs.isNotEmpty || _colors.isNotEmpty || _query.text.trim().isNotEmpty;

  void _clear() => setState(() {
    _langs.clear();
    _colors.clear();
    _query.clear();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context);
    final all = _ordered;
    final shown = _apply(all);
    final canvas = _canvas && _canvasAvailable;
    final header = <Widget>[
      _status(t),
      _tools(t, all),
      if (_filtered) _activeRow(t, shown.length),
      if (canvas) _layoutBar(t),
    ];

    if (canvas) {
      final ds = widget.dataset!;
      return Column(
        children: [
          ...header,
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PhotoCanvas(
                    ds: ds,
                    items: widget.items,
                    active: _filtered
                        ? {for (final p in shown) p.record!.index}
                        : null,
                    layout: _layout,
                    groupKey: _groupKey,
                    groupLabel: (k, v) => _groupValueLabel(t, k, v),
                    onOpen: widget.onOpen,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.md,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(t.canvasHint, style: AppText.caption()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      key: const PageStorageKey('explore-feed'),
      slivers: [
        for (final h in header) SliverToBoxAdapter(child: h),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  widget.items.isEmpty ? t.emptyBody : t.noMatch,
                  textAlign: TextAlign.center,
                  style: AppText.caption(),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childCount: shown.length,
              itemBuilder: (_, i) => PhotoTile(
                key: ValueKey(shown[i].key),
                item: shown[i],
                schema: widget.schema,
                onTap: () => widget.onOpen(shown[i]),
              ),
            ),
          ),
      ],
    );
  }

  /// 分组キー → 表示名（颜色/语言/各字段）。
  String _groupKeyLabel(AppLocalizations t, String key) => switch (key) {
    'cn' => t.toolColor,
    'lang' => t.toolLanguage,
    'car' => fieldLabel(t, '担体類型'),
    'q' => fieldLabel(t, '製作品質'),
    'dis' => fieldLabel(t, 'ディスコース類型'),
    'rel' => fieldLabel(t, '多言語関係'),
    'pos' => fieldLabel(t, '放置位置'),
    'tmp' => fieldLabel(t, '時間性'),
    _ => key,
  };

  String _groupValueLabel(AppLocalizations t, String key, String v) =>
      switch (key) {
        'cn' => colorDisplayName(t, v),
        'lang' => langDisplayName(t, v),
        _ => v.isEmpty ? '—' : v,
      };

  /// 画布の並べ方（照片墙 / 分组 / 色轮 / 色相×明度）。
  /// 分组を選び直す（選択中にもう一度押す）と、分组の次元を選べる。
  Widget _layoutBar(AppLocalizations t) {
    Widget chip(CanvasLayout l, String label) {
      final on = _layout == l;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          visualDensity: VisualDensity.compact,
          selectedColor: AppColors.textPrimary,
          labelStyle: AppText.caption().copyWith(
            fontSize: 12.5,
            color: on ? Colors.white : AppColors.textPrimary,
          ),
          showCheckmark: false,
          onSelected: (_) {
            if (l == CanvasLayout.group && on) {
              _pickGroupKey(t);
            } else {
              setState(() => _layout = l);
            }
          },
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        children: [
          chip(CanvasLayout.wall, t.layoutWall),
          chip(
            CanvasLayout.group,
            _layout == CanvasLayout.group
                ? '${t.layoutGroup} · ${_groupKeyLabel(t, _groupKey)} ▾'
                : t.layoutGroup,
          ),
          chip(CanvasLayout.wheel, t.layoutWheel),
          chip(CanvasLayout.hueLight, t.layoutHueLight),
        ],
      ),
    );
  }

  Future<void> _pickGroupKey(AppLocalizations t) => _sheet(
    t.groupBy,
    (setSheet) => [
      for (final k in kCanvasGroupKeys)
        ChoiceChip(
          label: Text(_groupKeyLabel(t, k)),
          selected: _groupKey == k,
          onSelected: (_) {
            setState(() => _groupKey = k);
            Navigator.pop(context);
          },
        ),
    ],
  );

  /// 探索データの接続状態（未接続・読込中・失敗）を一覧の上に出す。
  Widget _status(AppLocalizations t) {
    if (widget.usingShared && widget.load == ExploreLoad.ready) {
      return const SizedBox.shrink();
    }
    final (
      IconData icon,
      String title,
      String body,
      String? action,
      VoidCallback? onAction,
    ) = switch (widget.load) {
      ExploreLoad.loading => (
        Icons.cloud_download_outlined,
        t.exploreLoading,
        '',
        null,
        null,
      ),
      ExploreLoad.failed => (
        Icons.cloud_off_outlined,
        t.exploreLoadFailed(widget.loadError ?? ''),
        t.exploreNoSourceBody,
        t.retry,
        widget.onRetry,
      ),
      _ => (
        Icons.travel_explore,
        t.exploreNoSourceTitle,
        t.exploreNoSourceBody,
        t.goToSettings,
        widget.onOpenSettings,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: LLCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.link),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body().copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (body.isNotEmpty) Text(body, style: AppText.caption()),
                ],
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }

  Widget _tools(AppLocalizations t, List<PhotoItem> all) {
    final hasColor = all.any((p) => p.colorName.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          _ToolChip(
            label: t.toolLanguage,
            count: _langs.length,
            onTap: () => _pickLangs(t, all),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (hasColor) ...[
            _ToolChip(
              label: t.toolColor,
              count: _colors.length,
              onTap: () => _pickColors(t, all),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: AppText.body().copyWith(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: t.searchHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (_canvasAvailable) ...[
            const SizedBox(width: AppSpacing.sm),
            _ToolChip(
              label: _canvas ? t.viewFeed : t.viewCanvas,
              count: 0,
              icon: _canvas ? Icons.view_quilt_outlined : Icons.blur_on,
              onTap: () => _setCanvas(!_canvas),
            ),
          ],
        ],
      ),
    );
  }

  /// 効いている条件（削除可）と件数。
  Widget _activeRow(AppLocalizations t, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(t.photosCount(count), style: AppText.caption()),
          for (final c in _langs)
            InputChip(
              label: Text(langDisplayName(t, c)),
              visualDensity: VisualDensity.compact,
              onDeleted: () => setState(() => _langs.remove(c)),
            ),
          for (final c in _colors)
            InputChip(
              avatar: CircleAvatar(
                backgroundColor: Color(kColorSwatch[c] ?? 0xFF999999),
              ),
              label: Text(colorDisplayName(t, c)),
              visualDensity: VisualDensity.compact,
              onDeleted: () => setState(() => _colors.remove(c)),
            ),
          TextButton(onPressed: _clear, child: Text(t.clearFilters)),
        ],
      ),
    );
  }

  Map<String, int> _count(Iterable<List<String>> values) {
    final m = <String, int>{};
    for (final vs in values) {
      for (final v in vs) {
        m[v] = (m[v] ?? 0) + 1;
      }
    }
    return m;
  }

  Future<void> _pickLangs(AppLocalizations t, List<PhotoItem> all) async {
    final counts = _count(all.map(_langsOf));
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    await _sheet(
      t.toolLanguage,
      (setSheet) => [
        for (final c in keys)
          FilterChip(
            avatar: CircleAvatar(
              backgroundColor: langColor(widget.schema, c),
              radius: 5,
            ),
            label: Text('${langDisplayName(t, c)}  ${counts[c]}'),
            selected: _langs.contains(c),
            onSelected: (_) {
              setState(
                () => _langs.contains(c) ? _langs.remove(c) : _langs.add(c),
              );
              setSheet(() {});
            },
          ),
      ],
    );
  }

  Future<void> _pickColors(AppLocalizations t, List<PhotoItem> all) async {
    final counts = _count(
      all.where((p) => p.colorName.isNotEmpty).map((p) => [p.colorName]),
    );
    final keys = kColorSwatch.keys.where(counts.containsKey).toList();
    await _sheet(
      t.toolColor,
      (setSheet) => [
        for (final c in keys)
          FilterChip(
            avatar: CircleAvatar(
              backgroundColor: Color(kColorSwatch[c]!),
              radius: 7,
            ),
            label: Text('${colorDisplayName(t, c)}  ${counts[c]}'),
            selected: _colors.contains(c),
            onSelected: (_) {
              setState(
                () => _colors.contains(c) ? _colors.remove(c) : _colors.add(c),
              );
              setSheet(() {});
            },
          ),
      ],
    );
  }

  Future<void> _sheet(
    String title,
    List<Widget> Function(StateSetter setSheet) chips,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => LLBottomSheetScaffold(
          title: title,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(spacing: 8, runSpacing: 8, children: chips(setSheet)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  final IconData? icon; // 指定時は先頭にアイコン（下向き矢印なし＝切替ボタン）
  const _ToolChip({
    required this.label,
    required this.count,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return Material(
      color: on ? AppColors.textPrimary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.textPrimary),
                const SizedBox(width: 4),
              ],
              Text(
                on ? '$label · $count' : label,
                style: AppText.caption().copyWith(
                  fontSize: 13,
                  color: on ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (icon == null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: on ? Colors.white : AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 主题 ─────────────────────────

class _ThemesPage extends StatefulWidget {
  final AppSchema schema;
  final ExploreDataset? dataset;
  final List<PhotoItem> sharedItems;
  final ExploreLoad load;
  final void Function(PhotoItem) onOpen;
  final VoidCallback onOpenSettings;

  const _ThemesPage({
    required this.schema,
    required this.dataset,
    required this.sharedItems,
    required this.load,
    required this.onOpen,
    required this.onOpenSettings,
  });

  @override
  State<_ThemesPage> createState() => _ThemesPageState();
}

typedef _ThemeCard = ({
  ExploreTheme theme,
  List<PhotoItem> items,
  List<PhotoItem> cover,
});

class _ThemesPageState extends State<_ThemesPage>
    with AutomaticKeepAliveClientMixin {
  ExploreDataset? _builtFor;
  List<_ThemeCard> _cards = const [];

  @override
  bool get wantKeepAlive => true;

  /// テーマごとの写真と表紙（隣のカードと同じ写真が並ばないよう llmap-view と
  /// 同じく既出を後ろへ回す）。データが変わった時だけ作り直す。
  List<_ThemeCard> _build(ExploreDataset ds) {
    if (identical(_builtFor, ds)) return _cards;
    final used = <int>{};
    final cards = <_ThemeCard>[];
    for (final th in kExploreThemes) {
      final recs = th.pick(ds.records);
      if (recs.isEmpty) continue;
      final ordered = [
        ...recs.where((r) => !used.contains(r.index)),
        ...recs.where((r) => used.contains(r.index)),
      ];
      used.addAll(ordered.take(4).map((r) => r.index));
      cards.add((
        theme: th,
        items: [for (final r in recs) widget.sharedItems[r.index]],
        cover: [for (final r in ordered.take(4)) widget.sharedItems[r.index]],
      ));
    }
    _builtFor = ds;
    _cards = cards;
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context);
    final ds = widget.dataset;
    if (ds == null || widget.sharedItems.length != ds.records.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.collections_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.load == ExploreLoad.loading
                    ? t.exploreLoading
                    : t.themesNeedSource,
                textAlign: TextAlign.center,
                style: AppText.body(),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (widget.load != ExploreLoad.loading)
                LLSecondaryButton(
                  label: t.goToSettings,
                  expand: false,
                  onPressed: widget.onOpenSettings,
                ),
            ],
          ),
        ),
      );
    }
    final cards = _build(ds);
    return ListView.separated(
      key: const PageStorageKey('explore-themes'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (_, i) => _themeCard(t, cards[i]),
    );
  }

  Widget _themeCard(AppLocalizations t, _ThemeCard c) {
    final cover = c.cover.first;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThemeScreen(
            title: c.theme.title(t),
            subtitle: c.theme.subtitle(t),
            items: c.items,
            schema: widget.schema,
            onOpen: widget.onOpen,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: cover.placeholder),
              if (cover.image != null)
                Image(
                  image: ResizeImage(
                    cover.image!,
                    width: 900,
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
                    colors: [Color(0x00000000), Color(0xB0000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    t.photosCount(c.items.length),
                    style: AppText.caption().copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: [
                    for (final p in c.cover.skip(1).take(3))
                      Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: p.placeholder,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                          image: p.image == null
                              ? null
                              : DecorationImage(
                                  image: ResizeImage(p.image!, width: 120),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.theme.title(t),
                      style: AppText.sectionTitle().copyWith(
                        color: Colors.white,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.theme.subtitle(t),
                      style: AppText.caption().copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
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

/// 1 つの主题の写真一覧（瀑布流）。
class ThemeScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<PhotoItem> items;
  final AppSchema schema;
  final void Function(PhotoItem) onOpen;

  const ThemeScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.schema,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: AppText.sectionTitle()),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                '$subtitle · ${t.photosCount(items.length)}',
                style: AppText.caption(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
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
                onTap: () => onOpen(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
