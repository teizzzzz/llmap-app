/// 采集档案（相册型画廊, Step 12）。缩略图网格＋批量選択/削除＋筛选＋排序＋相册。
/// HomeScreen が記録の状態オーナーのまま、削除は onDeleteMany へ委譲する
/// （写真の安全削除は Home 側の共通経路。ここでは複製しない）。
/// 相册は端末内の整理機能（albums.json）で、記録本体・導出には影響しない。
library;

import 'package:flutter/material.dart';

import '../albums.dart';
import '../export_flow.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../record_ops.dart';
import '../store.dart';
import '../theme.dart' show statusBadge;
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import 'edit_sign_screen.dart';

class GalleryScreen extends StatefulWidget {
  final List<Sign> signs; // HomeScreen._signs の参照（共有）
  final AppSchema schema;
  /// 削除を Home に委譲（単発/批量とも同一経路。写真の孤児清掃込み）。
  final Future<void> Function(List<Sign> signs) onDeleteMany;
  final VoidCallback onChanged; // 保存後の Home 再描画・永続化

  const GalleryScreen({
    super.key,
    required this.signs,
    required this.schema,
    required this.onDeleteMany,
    required this.onChanged,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryFilter _filter = GalleryFilter();
  GallerySort _sort = GallerySort.newestFirst;

  // 归納状態視図（Step 12.1）。既定は未分類 = 整理待ち Inbox。
  // 具体的な相册を開いている間は適用しない（相册視図が優先）。
  AlbumStatusFilter _albumStatus = AlbumStatusFilter.unfiled;

  // 選択モード（iPhone 相册式: 長押しで開始、タップで増減）。
  bool _selecting = false;
  final Set<Sign> _selected = {};

  // 相册。null = すべての記録。
  List<Album> _albums = [];
  String? _albumId;

  @override
  void initState() {
    super.initState();
    // path_provider が使えない環境（widget テスト等）でも画面自体は動かす。
    LocalStore.instance.loadAlbums().then((a) {
      if (mounted) setState(() => _albums = a);
    }).catchError((_) {});
  }

  Album? get _currentAlbum {
    for (final a in _albums) {
      if (a.id == _albumId) return a;
    }
    return null;
  }

  // ── 表示対象（相册 or 归納状態 → 筛选 → 排序。表示のみで記録は変更しない） ──
  List<Sign> get _visible {
    final album = _currentAlbum;
    final Iterable<Sign> base = album != null
        // 相册視図: その相册の記録のみ（未分類/全部/分類済みは適用しない）
        ? widget.signs.where((s) => album.contains(s.id))
        // 主視図: 归納状態（既定 unfiled）で絞る
        : applyAlbumStatusFilter(widget.signs, _albums, _albumStatus);
    return sortedSigns(base.where(_filter.matches).toList(), _sort);
  }

  // multi=true の字段（主要言語など）は "/" 区切りを個々の値に展開する。
  List<String> _distinct(String key, {bool multi = false}) {
    final set = <String>{};
    for (final s in widget.signs) {
      final v = key == 'DataStatus' ? effectiveDataStatus(s) : s.get(key);
      if (v.isEmpty || v == '—') continue;
      if (multi) {
        set.addAll(splitMulti(v));
      } else {
        set.add(v);
      }
    }
    return set.toList();
  }

  Future<void> _saveAlbums() async {
    try {
      await LocalStore.instance.saveAlbums(_albums);
    } catch (_) {
      // 保存失敗（テスト環境等）でも画面上の相册操作は継続する
    }
  }

  // ── 編集（通常モードのタップ） ──
  Future<void> _edit(Sign s) async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSignScreen(sign: s, schema: widget.schema),
      ),
    );
    if (!mounted) return;
    if (r == 'deleted') {
      await widget.onDeleteMany([s]);
      _forgetDeleted([s]);
      setState(() {});
    } else if (r == 'saved') {
      widget.onChanged();
      setState(() {});
    }
  }

  // ── 選択モード ──
  /// 長押し起点はその項目を選択済みで開始、Select ボタン起点は空で開始
  /// （iPhone 相册と同じ）。
  void _enterSelection([Sign? s]) => setState(() {
        _selecting = true;
        _selected.clear();
        if (s != null) _selected.add(s);
      });

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(Sign s) => setState(() {
        if (!_selected.remove(s)) _selected.add(s);
      });

  void _toggleSelectAll() {
    final visible = _visible;
    setState(() {
      if (_selected.length >= visible.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(visible);
      }
    });
  }

  /// 削除済み記録の後始末: 選択集合と全相册の所属から外して保存する。
  void _forgetDeleted(List<Sign> deleted) {
    final ids = deleted.map((s) => s.id).where((id) => id.isNotEmpty).toList();
    _selected.removeAll(deleted);
    var changed = false;
    for (final a in _albums) {
      if (a.removeAll(ids) > 0) changed = true;
    }
    if (changed) _saveAlbums();
  }

  Future<void> _deleteSelected() async {
    final t = AppLocalizations.of(context);
    final targets = _selected.toList();
    if (targets.isEmpty) return;
    final ok = await showLLDialog<bool>(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.danger,
      title: t.deleteMultipleTitle(targets.length),
      message: t.deleteIrreversibleBody,
      primaryLabel: t.delete,
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: t.cancel,
      onSecondary: () => Navigator.pop(context, false),
    );
    if (ok != true || !mounted) return;
    await widget.onDeleteMany(targets);
    if (!mounted) return;
    _forgetDeleted(targets);
    _exitSelection();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.deletedCount(targets.length))));
  }

  // ── 相册操作 ──
  Future<String?> _askAlbumName({String? initial}) async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: initial ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(initial == null ? t.newAlbum : t.renameAlbum),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: t.albumNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(t.confirm)),
        ],
      ),
    );
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<Album?> _createAlbum() async {
    final name = await _askAlbumName();
    if (name == null) return null;
    final album = Album.create(name);
    setState(() => _albums.add(album));
    await _saveAlbums();
    return album;
  }

  Future<void> _renameAlbum(Album a) async {
    final name = await _askAlbumName(initial: a.name);
    if (name == null) return;
    setState(() => a.rename(name));
    await _saveAlbums();
  }

  /// 相册の削除は相册本体のみ。中の記録・写真は一切消さない。
  Future<void> _deleteAlbum(Album a) async {
    final t = AppLocalizations.of(context);
    final ok = await showLLDialog<bool>(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.danger,
      title: t.deleteAlbumTitle(a.name),
      message: t.deleteAlbumBody,
      primaryLabel: t.delete,
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: t.cancel,
      onSecondary: () => Navigator.pop(context, false),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _albums.remove(a);
      if (_albumId == a.id) _albumId = null;
    });
    await _saveAlbums();
  }

  void _albumChipMenu(Album a) {
    final t = AppLocalizations.of(context);
    showLLBottomSheet(context, title: a.name, children: [
      LLSheetTile(
          icon: Icons.drive_file_rename_outline,
          label: t.renameAlbum,
          onTap: () {
            Navigator.pop(context);
            _renameAlbum(a);
          }),
      LLSheetTile(
          icon: Icons.delete_outline,
          label: t.deleteAlbum,
          color: AppColors.danger,
          onTap: () {
            Navigator.pop(context);
            _deleteAlbum(a);
          }),
      LLSheetTile(
          icon: Icons.close,
          label: t.cancel,
          color: AppColors.textSecondary,
          showChevron: false,
          onTap: () => Navigator.pop(context)),
    ]);
  }

  Future<void> _addSelectedToAlbum() async {
    final t = AppLocalizations.of(context);
    if (_selected.isEmpty) return;
    // 戻り値: Album=既存相册を選択 / '_new_'=新規作成 / null=シートを閉じた。
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surfaceIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(t.addToAlbum, style: AppText.sectionTitle()),
            ),
            for (final a in _albums)
              ListTile(
                leading: const Icon(Icons.photo_album_outlined),
                title: Text(a.name, style: AppText.body()),
                subtitle: Text(t.recordsCount(a.recordIds.length),
                    style: AppText.caption()),
                onTap: () => Navigator.pop(ctx, a),
              ),
            ListTile(
              leading: const Icon(Icons.add,
                  color: AppColors.accentTerracotta),
              title: Text(t.newAlbum,
                  style: AppText.body()
                      .copyWith(color: AppColors.accentTerracotta)),
              onTap: () => Navigator.pop(ctx, '_new_'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return; // シート外タップ等は何もしない
    final target = picked is Album ? picked : await _createAlbum();
    if (target == null || !mounted) return;
    final ids = _selected.map((s) => s.id).where((id) => id.isNotEmpty);
    final added = target.addAll(ids);
    await _saveAlbums();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.addedToAlbum(added, target.name))));
  }

  Future<void> _removeSelectedFromAlbum() async {
    final t = AppLocalizations.of(context);
    final album = _currentAlbum;
    if (album == null || _selected.isEmpty) return;
    final removed =
        album.removeAll(_selected.map((s) => s.id).where((id) => id.isNotEmpty));
    await _saveAlbums();
    if (!mounted) return;
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.removedFromAlbum(removed))));
  }

  // ── 導出（Step 14: 範囲つき。実行は export_flow の共通経路） ──

  Future<void> _confirmAndExport(List<Sign> signs) async {
    if (!await confirmDatasetExport(context, signs.length)) return;
    if (!mounted) return;
    await runDatasetExport(context, signs: signs, schema: widget.schema);
    // 導出は非破壊なので選択状態は保持する（続けて相册追加・削除に使える）。
  }

  /// 選択モードの「選択中を書き出す」。0 件時はボタン側で無効化済み。
  Future<void> _exportSelected() => _confirmAndExport(exportCandidates(
        scope: ExportScope.selected,
        allSigns: widget.signs,
        selected: _selected,
      ));

  /// 通常モードの導出範囲シート（現在の表示 / 現在のアルバム / すべて）。
  void _openExportSheet() {
    final t = AppLocalizations.of(context);
    final visible = _visible;
    final album = _currentAlbum;
    final albumSigns = album == null
        ? const <Sign>[]
        : exportCandidates(
            scope: ExportScope.currentAlbum,
            allSigns: widget.signs,
            currentAlbum: album,
          );
    showLLBottomSheet(context, title: t.exportDataset, children: [
      // 現在の表示 = 相册視図・归納状態・筛选・排序を反映した表示リストそのもの
      LLSheetTile(
          icon: Icons.visibility_outlined,
          label: '${t.exportScopeCurrentView} (${visible.length})',
          onTap: () {
            Navigator.pop(context);
            _confirmAndExport(visible);
          }),
      if (album != null)
        LLSheetTile(
            icon: Icons.photo_album_outlined,
            label: '${t.exportScopeAlbum}: ${album.name} (${albumSigns.length})',
            onTap: () {
              Navigator.pop(context);
              _confirmAndExport(albumSigns);
            }),
      LLSheetTile(
          icon: Icons.folder_zip_outlined,
          label: '${t.allRecords} (${widget.signs.length})',
          onTap: () {
            Navigator.pop(context);
            _confirmAndExport(List<Sign>.of(widget.signs));
          }),
      // 任意の相册を選んで導出（範囲 5）。相册が無ければ出さない。
      if (_albums.isNotEmpty)
        LLSheetTile(
            icon: Icons.collections_bookmark_outlined,
            label: t.exportPickAlbum,
            onTap: () {
              Navigator.pop(context);
              _openAlbumExportPicker();
            }),
      LLSheetTile(
          icon: Icons.close,
          label: t.cancel,
          color: AppColors.textSecondary,
          showChevron: false,
          onTap: () => Navigator.pop(context)),
    ]);
  }

  /// 相册を1つ選んで導出する二段目シート（件数つき）。
  void _openAlbumExportPicker() {
    final t = AppLocalizations.of(context);
    showLLBottomSheet(context, title: t.exportPickAlbum, children: [
      for (final a in _albums)
        LLSheetTile(
            icon: Icons.photo_album_outlined,
            label:
                '${a.name} (${widget.signs.where((s) => a.contains(s.id)).length})',
            onTap: () {
              Navigator.pop(context);
              _confirmAndExport(exportCandidates(
                scope: ExportScope.album,
                allSigns: widget.signs,
                currentAlbum: a,
              ));
            }),
      LLSheetTile(
          icon: Icons.close,
          label: t.cancel,
          color: AppColors.textSecondary,
          showChevron: false,
          onTap: () => Navigator.pop(context)),
    ]);
  }

  // ── 排序シート ──
  void _openSortSheet() {
    final t = AppLocalizations.of(context);
    final options = [
      (GallerySort.newestFirst, t.sortNewestFirst, Icons.south),
      (GallerySort.oldestFirst, t.sortOldestFirst, Icons.north),
      (GallerySort.displayIdAsc, t.sortIdAsc, Icons.sort_by_alpha),
      (GallerySort.displayIdDesc, t.sortIdDesc, Icons.sort_by_alpha),
    ];
    showLLBottomSheet(context, title: t.sortTitle, children: [
      for (final (value, label, icon) in options)
        LLSheetTile(
          icon: _sort == value ? Icons.check : icon,
          label: label,
          color: _sort == value ? AppColors.accentTerracotta : null,
          showChevron: false,
          onTap: () {
            Navigator.pop(context);
            setState(() => _sort = value);
          },
        ),
    ]);
  }

  // ── 筛选シート（即時反映） ──
  void _openFilterSheet() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) {
          // シート内の変更を両方（シート・背後の一覧）へ即時反映する。
          void apply(VoidCallback fn) {
            sheetSetState(fn);
            setState(() {});
          }

          Widget chips<T>(String label, List<T> options, T? selected,
              String Function(T) nameOf, void Function(T?) onPick) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.caption()),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(t.all, selected == null, () => apply(() => onPick(null))),
                      for (final o in options)
                        _chip(nameOf(o), selected == o,
                            () => apply(() => onPick(selected == o ? null : o))),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget triState(String label, bool? value, void Function(bool?) set) {
            return chips<bool>(
              label,
              const [true, false],
              value,
              (v) => v ? t.yes : t.no,
              set,
            );
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        Text(t.filterTitle, style: AppText.sectionTitle()),
                        const Spacer(),
                        Text(t.resultsCount(_visible.length),
                            style: AppText.caption()),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        chips<String>(t.langFilter,
                            _distinct('主要言語', multi: true), _filter.language,
                            (v) => v, (v) => _filter.language = v),
                        chips<String>(t.sourceFilter, _distinct('設置主体'),
                            _filter.source, (v) => v, (v) => _filter.source = v),
                        chips<String>(t.filterMode, _distinct('EntryMode'),
                            _filter.entryMode, (v) => v,
                            (v) => _filter.entryMode = v),
                        chips<String>(t.filterStatus, _distinct('DataStatus'),
                            _filter.dataStatus, (v) => v,
                            (v) => _filter.dataStatus = v),
                        if (_distinct('地区コード').isNotEmpty)
                          chips<String>(t.filterArea, _distinct('地区コード'),
                              _filter.areaCode, (v) => v,
                              (v) => _filter.areaCode = v),
                        if (_distinct('採集者ID').isNotEmpty)
                          chips<String>(t.filterCollector, _distinct('採集者ID'),
                              _filter.collectorId, (v) => v,
                              (v) => _filter.collectorId = v),
                        triState(t.filterGps, _filter.hasGps,
                            (v) => _filter.hasGps = v),
                        triState(t.filterPhoto, _filter.hasPhoto,
                            (v) => _filter.hasPhoto = v),
                        triState(t.filterSource, _filter.hasSource,
                            (v) => _filter.hasSource = v),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: LLSecondaryButton(
                            label: t.clearFilters,
                            onPressed: () => apply(_filter.clear),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: LLPrimaryButton(
                            label: t.done,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── build ──
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final visible = _visible;
    final allVisibleSelected =
        visible.isNotEmpty && _selected.length >= visible.length;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: t.cancel,
                onPressed: _exitSelection,
              ),
              title: Text(t.selectedCount(_selected.length)),
              actions: [
                TextButton(
                  onPressed: visible.isEmpty ? null : _toggleSelectAll,
                  child:
                      Text(allVisibleSelected ? t.deselectAll : t.selectAll),
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: t.exportSelected,
                  onPressed: _selected.isEmpty ? null : _exportSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.photo_album_outlined),
                  tooltip: t.addToAlbum,
                  onPressed: _selected.isEmpty ? null : _addSelectedToAlbum,
                ),
                if (_albumId != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: t.removeFromAlbum,
                    onPressed:
                        _selected.isEmpty ? null : _removeSelectedFromAlbum,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.danger,
                  tooltip: t.delete,
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: Text(t.galleryTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: t.exportDataset,
                  onPressed: widget.signs.isEmpty ? null : _openExportSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: t.sortTitle,
                  onPressed: _openSortSheet,
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: _filter.isActive,
                    label: Text('${_filter.activeCount}'),
                    child: const Icon(Icons.filter_list),
                  ),
                  tooltip: t.filterTitle,
                  onPressed: _openFilterSheet,
                ),
                if (visible.isNotEmpty)
                  TextButton(
                    onPressed: _enterSelection,
                    child: Text(t.select),
                  ),
              ],
            ),
      body: Column(
        children: [
          _albumBar(t),
          // 归納状態の切替（主視図のみ。相册視図では隠して混乱を避ける）
          if (_albumId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LLSegmentedControl<AlbumStatusFilter>(
                segments: [
                  LLSegment(AlbumStatusFilter.unfiled, t.unfiled),
                  LLSegment(AlbumStatusFilter.all, t.all),
                  LLSegment(AlbumStatusFilter.filed, t.filed),
                ],
                selected: _albumStatus,
                activeColor: AppColors.accentTerracotta,
                activeTextColor: AppColors.surfaceIvory,
                onChanged: (v) => setState(() => _albumStatus = v),
              ),
            ),
          _resultsBar(t, visible.length),
          Expanded(
            child: visible.isEmpty
                ? _emptyState(t)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 232,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => _card(visible[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /// 空状態。優先順: 記録ゼロ → 筛选起因（noMatch）→ 相册空 → 归納状態別。
  Widget _emptyState(AppLocalizations t) {
    final String title;
    String? subtitle;
    if (widget.signs.isEmpty) {
      title = t.emptyTitle;
    } else if (_filter.isActive) {
      title = t.noMatch; // 筛选条件による空を最優先で伝える
    } else if (_currentAlbum != null) {
      title = t.albumEmpty;
    } else if (_albumStatus == AlbumStatusFilter.unfiled) {
      title = t.noUnfiledRecords;
      subtitle = t.allRecordsFiled;
    } else if (_albumStatus == AlbumStatusFilter.filed) {
      title = t.noFiledRecords;
      subtitle = t.recordsAddedToAlbumsAppearHere;
    } else {
      title = t.emptyTitle; // all で空 = 記録ゼロ（通常は先頭分岐で到達しない）
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style:
                  AppText.body().copyWith(color: AppColors.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppText.caption()),
          ],
        ],
      ),
    );
  }

  /// 相册切替バー（All Records / 各相册 / 新規）。長押しで改名・削除。
  Widget _albumBar(AppLocalizations t) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 7),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _chip(t.allRecords, _albumId == null,
                () => setState(() => _albumId = null)),
          ),
          for (final a in _albums)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                '${a.name} (${widget.signs.where((s) => a.contains(s.id)).length})',
                _albumId == a.id,
                () => setState(() => _albumId = a.id),
                onLongPress: () => _albumChipMenu(a),
              ),
            ),
          _chip('+ ${t.newAlbum}', false, _createAlbum),
        ],
      ),
    );
  }

  /// 件数＋筛选状態の行。
  Widget _resultsBar(AppLocalizations t, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 4),
      child: Row(
        children: [
          Text(t.resultsCount(count), style: AppText.caption()),
          const Spacer(),
          if (_filter.isActive)
            GestureDetector(
              onTap: () => setState(_filter.clear),
              child: Text(
                t.clearFilters,
                style: AppText.caption().copyWith(
                    color: AppColors.accentTerracotta,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {VoidCallback? onLongPress, Color? dotColor}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
    final selected = _selected.contains(s);
    final card = LLCard(
      padding: EdgeInsets.zero,
      onTap: _selecting ? () => _toggle(s) : () => _edit(s),
      onLongPress: _selecting ? null : () => _enterSelection(s),
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

    if (!_selecting) return card;
    // 選択モード: check circle と選択枠を重ねる（iPhone 相册式）。
    return Stack(
      children: [
        Positioned.fill(child: card),
        if (selected)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: AppColors.accentTerracotta, width: 2.5),
                ),
              ),
            ),
          ),
        Positioned(
          top: 6,
          left: 6,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: selected
                    ? AppColors.accentTerracotta
                    : AppColors.borderSubtle,
              ),
            ),
          ),
        ),
      ],
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
