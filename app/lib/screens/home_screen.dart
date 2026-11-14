import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../albums.dart';
import '../capture.dart';
import '../capture_mode.dart';
import '../explore/dataset.dart';
import '../explore/photo_item.dart';
import '../explore/relations.dart';
import '../export_flow.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../record_ops.dart';
import '../settings.dart';
import '../store.dart';
import '../theme/tokens.dart';
import '../widgets/explore/photo_detail.dart';
import '../widgets/explore/relations_section.dart';
import '../widgets/ll/ll.dart';
import '../widgets/map/ll_map_view.dart';
import 'crop_screen.dart';
import 'edit_sign_screen.dart';
import 'explore_tab.dart';
import 'gallery_screen.dart';
import 'my_records_tab.dart';

/// アプリの外枠：底部ナビ「地図 ｜ 拍照（大）｜ 探索」。我的は探索の中の Tab。
/// _signs（端末の記録）と探索データの状態オーナーで、採集・保存・削除・
/// 导出・設定の中核フローもここに残す（各タブは表示と操作の委譲だけ）。
/// 起動時は地図タブ（従来どおり地図から入る）。
class HomeScreen extends StatefulWidget {
  final AppSchema schema;
  const HomeScreen({super.key, required this.schema});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 地図抽屉の高さ（画面に対する割合）。
const double _sheetMin = 0.16;
const double _sheetMid = 0.5;
const double _sheetMax = 0.92;

/// 抽屉の「範囲内」一覧に並べる上限（多すぎると一覧が重くなる）。
const int _inViewCap = 240;

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<Sign> _signs = [];
  String _area = 'OOK'; // 既定の地点コード（新大久保 Shin-Ōkubo）
  int _nextSeq = 1;
  bool _opening = false; // 二重起動防止
  AiConfig _ai = AiConfig();
  String _collector = ''; // 採集者ID（設定で自動生成/自定义）。SignID に入る。
  CaptureMode _mode = CaptureMode.quick; // 採集モード（既定 = デフォルトモード）

  // 外枠
  int _tab = 0; // 0=地図 1=探索（我的は探索ページ内の Tab）

  // 探索データ（llmap-view の公開データ。読み取り専用）
  String _exploreUrl = '';
  ExploreLoad _exploreLoad = ExploreLoad.none;
  String? _exploreError;
  ExploreDataset? _dataset;
  List<PhotoItem> _shared = const []; // records と同じ並び
  RelationIndex? _rel; // 「接下来探索」の関連（探索データ単位）

  // 地図タブの表示状態
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  LLMapLayer _layer = LLMapLayer.map;
  LatLngBounds? _view; // いまの地図範囲（抽屉一覧の対象）
  PhotoItem? _focus; // 抽屉で详情を出している写真
  ({LatLng center, double zoom})? _beforeFocus; // 详情に入る前の地図位置
  // 起動時の現在地センタリング用。
  Future<({double lat, double lng})?>? _initialGps;
  bool _centeredOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadAiConfig().then((c) {
      if (mounted) setState(() => _ai = c);
    });
    loadCollectorId().then((id) {
      if (mounted) setState(() => _collector = id);
    });
    loadCaptureMode().then((m) {
      if (mounted) setState(() => _mode = m);
    });
    _initialGps = currentGps(); // 起動と同時に現在地取得を開始
    _loadSaved();
    _recoverLostData();
    _initExplore();
  }

  /// 地図準備完了時：現在地へ移動（取得不可なら記録範囲）。1回だけ。
  Future<void> _onMapReady() async {
    if (_centeredOnce) return;
    final gps = await _initialGps;
    if (!mounted || _centeredOnce) return;
    if (gps != null) {
      _centeredOnce = true;
      _map.move(LatLng(gps.lat, gps.lng), 16);
    } else if (_located.isNotEmpty) {
      _centeredOnce = true;
      _fitRecords();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheet.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recoverLostData();
  }

  // ── 位置を持つ sign と中心点 ──
  List<Sign> get _located =>
      _signs.where((s) => s.lat != null && s.lng != null).toList();

  LatLng get _center {
    final pts = _located;
    if (pts.isEmpty) return const LatLng(35.7010, 139.7003); // 新大久保
    final lat = pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((s) => s.lng!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  /// 自分の記録を新しい順に（探索の代替・我的・地図抽屉で共用）。
  List<PhotoItem> get _mineItems =>
      [for (final s in _signs.reversed) PhotoItem.fromSign(s)];

  // ── 探索データ ──
  Future<void> _initExplore() async {
    _exploreUrl = await loadExploreUrl();
    await _loadExplore();
  }

  Future<void> _loadExplore() async {
    if (normalizeExploreUrl(_exploreUrl).isEmpty) {
      if (mounted) {
        setState(() {
          _exploreLoad = ExploreLoad.none;
          _dataset = null;
          _shared = const [];
          _rel = null;
        });
      }
      return;
    }
    setState(() {
      _exploreLoad = ExploreLoad.loading;
      _exploreError = null;
    });
    try {
      final ds = await fetchExploreDataset(_exploreUrl);
      if (!mounted) return;
      setState(() {
        _dataset = ds;
        _shared = [for (final r in ds.records) PhotoItem.fromRecord(ds, r)];
        _rel = RelationIndex(ds);
        _exploreLoad = ExploreLoad.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exploreLoad = ExploreLoad.failed;
        _exploreError = '$e';
        _dataset = null;
        _shared = const [];
        _rel = null;
      });
    }
  }

  // ── データ復元・永続化（不変の中核フロー） ──
  Future<void> _loadSaved() async {
    final p = await LocalStore.instance.loadProject();
    if (p == null || !mounted) return;
    setState(() {
      _signs
        ..clear()
        ..addAll(p.signs);
      _area = p.area;
      _nextSeq = p.nextSeq;
    });
  }

  Future<void> _persist() =>
      LocalStore.instance.saveProject(_signs, _area, _nextSeq);

  /// 記録を削除し、**残る記録から参照されない**写真ファイルだけを一緒に消す
  /// （複数 sign が同じ元写真を共有するケースを壊さない）。単発削除・
  /// Gallery の批量削除の両方がこの経路を通る。
  Future<void> _deleteSigns(List<Sign> toDelete) async {
    if (toDelete.isEmpty) return;
    final del = toDelete.toSet();
    final remaining = _signs.where((s) => !del.contains(s)).toList();
    final orphans = orphanedPhotos(deleting: del, remaining: remaining);
    setState(() {
      _signs
        ..clear()
        ..addAll(remaining);
      if (_focus?.sign != null && del.contains(_focus!.sign)) _focus = null;
    });
    await _persist(); // 先に記録を確定してから写真を消す（途中断でも参照切れ側に倒す）
    await LocalStore.instance.deletePhotos(orphans);
  }

  /// 撮影直後に Activity 再生成で失われた写真を image_picker から復旧。
  Future<void> _recoverLostData() async {
    if (!isMobile) return;
    final lost = await ImagePicker().retrieveLostData();
    if (lost.isEmpty || lost.file == null) return;
    final x = lost.file!;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    _openCrop(bytes, x.name);
  }

  /// 全ページ共通の拍照ボタン：拍照 / 相册から取り込みを選んで採集へ。
  Future<void> _startCapture() async {
    if (_opening) return;
    final shot = await capturePhoto(context);
    if (shot == null || !mounted) return;
    _openCrop(shot.bytes, shot.fileName);
  }

  /// 框选→字段入力→ローカル保存→成功Dialog。中核業務フローは不変。
  Future<void> _openCrop(Uint8List bytes, String fileName) async {
    if (_opening) return;
    _opening = true;
    try {
      final result = await Navigator.push<List<Sign>>(
        context,
        MaterialPageRoute(
          builder: (_) => CropScreen(
            schema: widget.schema,
            imageBytes: bytes,
            fileName: fileName,
            area: _area,
            seq: _nextSeq,
            collector: _collector,
            aiConfig: _ai,
            mode: _mode,
          ),
        ),
      );
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          _signs.addAll(result);
          _nextSeq++;
        });
        await _persist();
        if (!mounted) return;
        await _showSavedDialog();
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _showSavedDialog() {
    final t = AppLocalizations.of(context);
    // 保存メッセージは採集モードで変える（default=後で補完可 / expert=研究記録）。
    final message = switch (_mode) {
      CaptureMode.quick => t.savedQuick,
      CaptureMode.standard => t.savedStandard,
      CaptureMode.research => t.savedResearch,
    };
    return showLLDialog(
      context,
      icon: Icons.check_rounded,
      iconColor: AppColors.success,
      title: t.savedTitle,
      message: message,
      primaryLabel: t.ok,
    );
  }

  /// Dataset Package の導出（Step 14: 範囲選択つき）。
  /// 入口は我的の「更多 → データをエクスポート」。押した直後に範囲
  /// （全部 / 未分類 / 分類済み / 相册指定）を選ぶ。実行は export_flow。
  /// 表示中の Gallery 筛选・選択・相册の導出は Gallery 側の入口が担う。
  Future<void> _export() async {
    if (_signs.isEmpty) return;
    // 归納状態の件数計算のため相册を読む。**読めなかった時は归納状態の
    // 選択肢を出さない** — albums=[] のまま出すと「未分類=全件」という
    // 誤った件数を見せ、意図しない全件導出につながるため（誠実に降級）。
    List<Album>? albums;
    try {
      albums = await LocalStore.instance.loadAlbums();
    } catch (_) {
      albums = null;
    }
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    final all = exportCandidates(scope: ExportScope.all, allSigns: _signs);
    final unfiled = albums == null
        ? const <Sign>[]
        : exportCandidates(
            scope: ExportScope.unfiled, allSigns: _signs, albums: albums);
    final filed = albums == null
        ? const <Sign>[]
        : exportCandidates(
            scope: ExportScope.filed, allSigns: _signs, albums: albums);
    final schema = widget.schema;
    showLLBottomSheet(context, title: t.exportDataset, children: [
      LLSheetTile(
          icon: Icons.folder_zip_outlined,
          label: '${t.allRecords} (${all.length})',
          onTap: () {
            Navigator.pop(context);
            confirmAndRunDatasetExport(context, signs: all, schema: schema);
          }),
      if (albums != null) ...[
        LLSheetTile(
            icon: Icons.inbox_outlined,
            label: '${t.unfiled} (${unfiled.length})',
            onTap: () {
              Navigator.pop(context);
              confirmAndRunDatasetExport(context,
                  signs: unfiled, schema: schema);
            }),
        LLSheetTile(
            icon: Icons.photo_album_outlined,
            label: '${t.filed} (${filed.length})',
            onTap: () {
              Navigator.pop(context);
              confirmAndRunDatasetExport(context,
                  signs: filed, schema: schema);
            }),
        // 任意の相册を選んで導出（範囲 5）。相册が無ければ出さない。
        if (albums.isNotEmpty)
          LLSheetTile(
              icon: Icons.collections_bookmark_outlined,
              label: t.exportPickAlbum,
              onTap: () {
                Navigator.pop(context);
                showAlbumExportPicker(context,
                    albums: albums!, allSigns: _signs, schema: schema);
              }),
      ],
      LLSheetTile(
          icon: Icons.close,
          label: t.cancel,
          color: AppColors.textSecondary,
          showChevron: false,
          onTap: () => Navigator.pop(context)),
    ]);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<SettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          ai: _ai,
          collectorId: _collector,
          captureMode: _mode,
          exploreUrl: _exploreUrl,
        ),
      ),
    );
    if (result == null) return;
    await saveAiConfig(result.ai);
    await saveCollectorId(result.collectorId);
    await saveCaptureMode(result.captureMode);
    await saveExploreUrl(result.exploreUrl);
    final exploreChanged = result.exploreUrl.trim() != _exploreUrl.trim();
    if (mounted) {
      setState(() {
        _ai = result.ai;
        _collector = result.collectorId;
        _mode = result.captureMode;
        _exploreUrl = result.exploreUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
      );
      if (exploreChanged) _loadExplore();
    }
  }

  /// 相册と一括管理（旧「采集档案」）。HomeScreen が状態オーナーのまま委譲。
  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          signs: _signs,
          schema: widget.schema,
          onDeleteMany: _deleteSigns, // 単発/批量とも写真安全削除の同一経路
          onChanged: () {
            setState(() {});
            _persist();
          },
        ),
      ),
    );
  }

  Future<void> _editSign(Sign sign) async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSignScreen(sign: sign, schema: widget.schema),
      ),
    );
    if (!mounted) return;
    if (r == 'deleted') {
      await _deleteSigns([sign]);
    } else if (r == 'saved') {
      setState(() {
        // 抽屉の详情を最新の内容で描き直す。
        if (_focus?.sign == sign) _focus = PhotoItem.fromSign(sign);
      });
      _persist();
    }
  }

  Future<void> _editArea() async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: _area);
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.areaDialogTitle),
        content: TextField(
          controller: ctrl,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'OOK / YKH / SKO ...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.toUpperCase()),
              child: Text(t.confirm)),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      setState(() => _area = v.trim());
      _persist();
    }
  }

  // ── 照片详情（探索・我的からは全画面、地図では抽屉） ──

  /// 详情の末尾に置く「接下来探索」。探索データの写真は 6 種の関連、
  /// 自分の記録は位置があれば「就在附近」（探索データの近い写真）だけ。
  /// [inMap] のとき、関連一覧から選んだ写真は地図抽屉の详情で開く。
  Widget? _relationsFor(PhotoItem item, {bool inMap = false}) {
    final rel = _rel;
    if (rel == null) return null;
    final List<Relation> rels;
    if (item.record != null) {
      rels = rel.of(item.record!.index);
    } else if (item.hasLocation) {
      final near = rel.nearby(item.lat!, item.lng!);
      rels = near == null ? const [] : [near];
    } else {
      rels = const [];
    }
    if (rels.isEmpty) return null;
    final t = AppLocalizations.of(context);
    return RelationsSection(
      relations: rels,
      shared: _shared,
      onOpen: (r) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ThemeScreen(
            title: relTitle(t, r),
            subtitle: relSubtitle(t, r),
            items: [for (final j in r.items) _shared[j]],
            schema: widget.schema,
            onOpen: inMap
                ? (p) {
                    Navigator.pop(ctx);
                    _focusOnMap(p);
                  }
                : _openDetail,
          ),
        ),
      ),
    );
  }

  void _openDetail(PhotoItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PhotoDetailScreen(
          item: item,
          schema: widget.schema,
          footer: _relationsFor(item),
          onShowOnMap: () {
            Navigator.pop(ctx);
            _showOnMap(item);
          },
          onEdit: item.sign == null
              ? null
              : () {
                  Navigator.pop(ctx);
                  _editSign(item.sign!);
                },
        ),
      ),
    );
  }

  /// 「在地图上看」：地図タブへ切り替え、その写真を抽屉の详情で開く。
  void _showOnMap(PhotoItem item) {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusOnMap(item));
  }

  /// 地図の点／抽屉の写真をタップ：同じ抽屉を详情に切り替え、地図で強調する。
  void _focusOnMap(PhotoItem item) {
    if (!mounted) return;
    final cam = _map.camera;
    _beforeFocus ??= (center: cam.center, zoom: cam.zoom);
    setState(() => _focus = item);
    if (item.hasLocation) {
      final point = LatLng(item.lat!, item.lng!);
      final zoom = math.max(cam.zoom, 17.0);
      _map.move(point, zoom);
      // 抽屉（画面の下半分）に隠れないよう、点を画面の上寄りに置く。
      final moved = _map.camera;
      final size = moved.nonRotatedSize;
      final center = moved.pointToLatLng(
          math.Point(size.x / 2, size.y / 2 + size.y * 0.2));
      _map.move(center, zoom);
    }
    if (_sheet.isAttached && _sheet.size < _sheetMid - 0.01) {
      _sheet.animateTo(_sheetMid,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    }
  }

  /// 详情 → 一覧。地図位置も详情に入る前へ戻す。
  void _backToList() {
    final before = _beforeFocus;
    setState(() {
      _focus = null;
      _beforeFocus = null;
    });
    if (before != null) _map.move(before.center, before.zoom);
  }

  /// 当前位置へ移動。GPS取得不可なら記録範囲にフィット。
  Future<void> _locate() async {
    final gps = await currentGps();
    if (!mounted) return;
    if (gps != null) {
      _map.move(LatLng(gps.lat, gps.lng), 16);
    } else {
      _fitRecords();
    }
  }

  void _fitRecords() {
    final pts = _located;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(LatLng(pts.first.lat!, pts.first.lng!), 17);
      return;
    }
    var minLa = pts.first.lat!, maxLa = pts.first.lat!;
    var minLn = pts.first.lng!, maxLn = pts.first.lng!;
    for (final s in pts) {
      minLa = s.lat! < minLa ? s.lat! : minLa;
      maxLa = s.lat! > maxLa ? s.lat! : maxLa;
      minLn = s.lng! < minLn ? s.lng! : minLn;
      maxLn = s.lng! > maxLn ? s.lng! : maxLn;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLa, minLn), LatLng(maxLa, maxLn)),
      padding: const EdgeInsets.all(60),
    ));
  }

  // ── 画面 ──

  @override
  Widget build(BuildContext context) {
    final mine = _mineItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _FadeIndexedStack(
        index: _tab,
        children: [
          _mapPage(mine),
          ExploreTab(
            schema: widget.schema,
            load: _exploreLoad,
            loadError: _exploreError,
            dataset: _dataset,
            sharedItems: _shared,
            mineItems: mine,
            onOpen: _openDetail,
            onOpenSettings: _openSettings,
            onRetry: _loadExplore,
            mineView: MyRecordsTab(
              schema: widget.schema,
              items: mine,
              onOpen: _openDetail,
              onManage: _openGallery,
              onExport: _export,
              onEditArea: _editArea,
              areaLabel: '$_area #$_nextSeq',
            ),
          ),
        ],
      ),
      bottomNavigationBar: _NavDock(
        index: _tab,
        onSelect: (i) => setState(() => _tab = i),
        onCapture: _startCapture,
      ),
    );
  }

  Widget _mapPage(List<PhotoItem> mine) {
    final t = AppLocalizations.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final located = _located;
    return Stack(
      children: [
        LLMapView<int>(
          controller: _map,
          signs: located,
          schema: widget.schema,
          layer: _layer,
          selected: _focus?.sign,
          initialCenter: _center,
          initialZoom: located.isEmpty ? 15 : 16,
          onMapReady: _onMapReady,
          dots: [
            for (final p in _shared)
              if (p.hasLocation)
                LLMapDot<int>(
                  LatLng(p.lat!, p.lng!),
                  // 共有写真は灰の小点（自分の記録＝黒のピンと見分ける）。
                  AppColors.textSecondary,
                  p.record!.index,
                ),
          ],
          onDotTap: (i) => _focusOnMap(_shared[i]),
          highlight: _focus != null && _focus!.hasLocation && !_focus!.mine
              ? LatLng(_focus!.lat!, _focus!.lng!)
              : null,
          onCameraIdle: (cam) => setState(() => _view = cam.visibleBounds),
          onMarkerTap: (s) => _focusOnMap(PhotoItem.fromSign(s)),
        ),

        // 地図制御（Map/Satellite ＋ 現在地）
        Positioned(
          top: topInset + AppSpacing.md,
          left: 0,
          right: 0,
          child: Center(
            child: LLSegmentedControl<LLMapLayer>(
              segments: [
                LLSegment(LLMapLayer.map, t.layerMap),
                LLSegment(LLMapLayer.satellite, t.layerSatellite),
              ],
              selected: _layer,
              onChanged: (v) => setState(() => _layer = v),
            ),
          ),
        ),
        Positioned(
          top: topInset + AppSpacing.md,
          right: AppSpacing.lg,
          child: LLIconButton(
              icon: Icons.my_location,
              tooltip: t.currentLocation,
              onPressed: _locate),
        ),

        // 下部抽屉：範囲内の写真一覧 ⇄ 写真详情（同じ抽屉で切替）
        DraggableScrollableSheet(
          controller: _sheet,
          minChildSize: _sheetMin,
          initialChildSize: _sheetMin,
          maxChildSize: _sheetMax,
          snap: true,
          snapSizes: const [_sheetMin, _sheetMid, _sheetMax],
          builder: (ctx, scroll) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              boxShadow: AppShadows.floating,
            ),
            clipBehavior: Clip.antiAlias,
            child: _focus == null
                ? _inViewList(t, scroll, mine)
                : PopScope(
                    // 地図タブ表示中の戻る操作は「详情 → 一覧」に使う
                    // （アプリを閉じない）。他タブ表示中は通常どおり。
                    canPop: _tab != 0,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) _backToList();
                    },
                    child: PhotoDetailView(
                      key: ValueKey(_focus!.key),
                      item: _focus!,
                      schema: widget.schema,
                      controller: scroll,
                      maxImageHeight: 300,
                      header: Column(
                        children: [
                          const _Handle(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xs, 0, AppSpacing.lg, 0),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _backToList,
                                  icon: const Icon(Icons.chevron_left),
                                  label: Text(t.backToList),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onEdit: _focus!.sign == null
                          ? null
                          : () => _editSign(_focus!.sign!),
                      footer: _relationsFor(_focus!, inMap: true),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// 抽屉の一覧：いまの地図範囲に入っている写真（自分の記録が先）。
  Widget _inViewList(
      AppLocalizations t, ScrollController scroll, List<PhotoItem> mine) {
    final view = _view;
    bool inView(PhotoItem p) =>
        p.hasLocation &&
        (view == null || view.contains(LatLng(p.lat!, p.lng!)));
    final sharedIn = _shared.where(inView).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    final all = [...mine.where(inView), ...sharedIn];
    final shown = all.take(_inViewCap).toList();
    return CustomScrollView(
      controller: scroll,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Handle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 2, AppSpacing.lg, AppSpacing.sm),
                child: Text(t.mapInView(all.length),
                    style: AppText.sectionTitle().copyWith(fontSize: 16)),
              ),
              if (all.length > shown.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: Text(t.mapInViewCapped(shown.length),
                      style: AppText.caption()),
                ),
            ],
          ),
        ),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(t.mapInViewEmpty,
                  textAlign: TextAlign.center, style: AppText.caption()),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) => _thumb(shown[i]),
            ),
          ),
      ],
    );
  }

  Widget _thumb(PhotoItem p) {
    final img = p.image;
    return GestureDetector(
      onTap: () => _focusOnMap(p),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: p.placeholder.withValues(alpha: 0.55)),
            if (img != null)
              Image(
                image: ResizeImage(img, width: 260,
                    policy: ResizeImagePolicy.fit),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      );
}

/// 地図／探索の切替：同じ位置で重ね、選んだ方をふわっと出す（フェード＋
/// わずかな拡大）。IndexedStack と同じく両方の状態（地図の位置・一覧の
/// スクロール）は保持し、見えていない方は操作・アニメーションを止める。
class _FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const _FadeIndexedStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: ExcludeSemantics(
              excluding: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: i == index ? 1 : 0.985,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: TickerMode(enabled: i == index, child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 底部ナビ（iOS のタブバー風）：画面幅いっぱいの白い帯＋上端の細い区切り線、
/// アイコンの下に小さなラベル、選択中は黒・それ以外は灰。
/// 並びは「地図 ｜ 拍照 ｜ 探索」で、真ん中の拍照だけ大きな黒い円。
/// 帯の中に収めるので、写真・地図操作・抽屉には重ならない。
/// 動き：タブは選ばれた瞬間にアイコンが小さく弾み（輪郭→塗り）、色がなめらかに
/// 変わる。拍照は押している間だけ縮み、離すと戻る。どちらも軽い触覚フィードバック。
class _NavDock extends StatelessWidget {
  final int index; // 0=地図 1=探索
  final ValueChanged<int> onSelect;
  final VoidCallback onCapture;

  const _NavDock({
    required this.index,
    required this.onSelect,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void select(int i) {
      if (i != index) HapticFeedback.selectionClick();
      onSelect(i);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Color(0x1F000000), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map,
                  label: t.navMap,
                  selected: index == 0,
                  onTap: () => select(0),
                ),
              ),
              _ShutterButton(label: t.newCollection, onTap: onCapture),
              Expanded(
                child: _NavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore,
                  label: t.navExplore,
                  selected: index == 1,
                  onTap: () => select(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _on = AppColors.textPrimary;
  static const _off = Color(0xFF999999);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: selected ? _on : _off),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (context, color, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 選ばれた瞬間だけ 0.8 → 1 に弾む（key が変わると最初から再生）。
              TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: selected ? 0.8 : 1, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, a) =>
                      FadeTransition(opacity: a, child: child),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: 25,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 真ん中の拍照ボタン：押している間だけ少し縮み、離すとばねのように戻る。
class _ShutterButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ShutterButton({required this.label, required this.onTap});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: Duration(milliseconds: _down ? 90 : 320),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _down ? AppColors.charcoal : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: _down ? null : AppShadows.card,
            ),
            child: const Icon(
              Icons.photo_camera,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
