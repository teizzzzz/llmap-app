import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../capture.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../settings.dart';
import '../store.dart';
import '../theme/tokens.dart';
import '../version.dart';
import '../widgets/ll/ll.dart';
import '../widgets/ll_sign_card.dart';
import '../widgets/map/ll_map_detail_card.dart';
import '../widgets/map/ll_map_legend.dart';
import '../widgets/map/ll_map_view.dart';
import 'crop_screen.dart';
import 'edit_sign_screen.dart';
import 'gallery_screen.dart';

/// 採集ホーム（地図主体）。_signs の状態オーナー。地図表示・採集入口・
/// 記録パネル・导出・設定・本地保存の中核フローを担う。
class HomeScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  const HomeScreen({super.key, required this.api, required this.schema});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<Sign> _signs = [];
  String _area = 'OOK'; // 既定の地点コード（新大久保 Shin-Ōkubo）
  int _nextSeq = 1;
  bool _opening = false; // 二重起動防止
  AiConfig _ai = AiConfig();
  String _collector = ''; // 採集者ID（設定で自動生成/自定义）。SignID に入る。

  // 地図主体首页の表示状態
  final _map = MapController();
  Sign? _selected;
  LLMapLayer _layer = LLMapLayer.map;
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
    _initialGps = currentGps(); // 起動と同時に現在地取得を開始
    _loadSaved();
    _recoverLostData();
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
    if (pts.isEmpty) return const LatLng(35.6021, 139.7011);
    final lat = pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((s) => s.lng!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
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
            api: widget.api,
            schema: widget.schema,
            imageBytes: bytes,
            fileName: fileName,
            area: _area,
            seq: _nextSeq,
            collector: _collector,
            aiConfig: _ai,
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
    return showLLDialog(
      context,
      icon: Icons.check_rounded,
      iconColor: AppColors.success,
      title: t.savedTitle,
      message: t.savedBody,
      primaryLabel: t.backToMap,
    );
  }

  /// CSV＋写真を ZIP で一括エクスポート（端末内生成・進捗ダイアログ表示）。
  Future<void> _export() async {
    if (_signs.isEmpty) return;
    final t = AppLocalizations.of(context);
    final progress = ValueNotifier<({int done, int total})>((done: 0, total: 0));
    final sw = Stopwatch()..start();
    // 進捗ダイアログは1回だけ閉じる（success と catch の二重 pop で
    // 本体ページまで pop してしまい黒画面になるのを防ぐ）。
    var dialogOpen = true;
    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LLProgressDialog(
        title: t.exporting,
        unit: t.unitPhotos,
        progress: progress,
      ),
    );
    try {
      final zipPath = await LocalStore.instance.buildBundle(
        _signs,
        widget.schema.csvHeader,
        onProgress: (done, total) =>
            progress.value = (done: done, total: total),
      );
      // 少量でも進捗→完成が見えるよう、最低 ~0.9 秒は表示する。
      final remain = 900 - sw.elapsedMilliseconds;
      if (remain > 0) {
        await Future.delayed(Duration(milliseconds: remain));
      }
      if (!mounted) return;
      closeDialog(); // 進捗ダイアログを閉じる
      if (isMobile) {
        // iPad では sharePositionOrigin 必須（無いと presentation で例外）。
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'LLMap',
          sharePositionOrigin:
              box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      } else {
        final dir =
            Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
        final dest = File('$dir/Downloads/llmap_export.zip');
        await dest.parent.create(recursive: true);
        await File(zipPath).copy(dest.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.exportedTo(dest.path))),
          );
        }
      }
    } catch (e) {
      closeDialog(); // 進捗ダイアログを閉じる（まだ開いていれば）
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.exportFailed('$e'))));
      }
    } finally {
      progress.dispose();
    }
  }

  Future<void> _openSettings() async {
    final result =
        await Navigator.push<({String baseUrl, AiConfig ai, String collectorId})>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          baseUrl: widget.api.baseUrl,
          ai: _ai,
          collectorId: _collector,
        ),
      ),
    );
    if (result == null) return;
    await saveBaseUrl(result.baseUrl);
    await saveAiConfig(result.ai);
    await saveCollectorId(result.collectorId);
    widget.api.baseUrl = result.baseUrl;
    if (mounted) {
      setState(() {
        _ai = result.ai;
        _collector = result.collectorId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
      );
    }
  }

  /// 采集档案（画廊）を開く。HomeScreen が状態オーナーのまま編集/削除を委譲。
  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          signs: _signs,
          schema: widget.schema,
          onDelete: (s) {
            setState(() => _signs.remove(s));
            _persist();
          },
          onChanged: () {
            setState(() {});
            _persist();
          },
        ),
      ),
    );
  }

  Future<void> _editSign(int i) async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSignScreen(sign: _signs[i], schema: widget.schema),
      ),
    );
    if (!mounted) return;
    if (r == 'deleted') {
      setState(() => _signs.removeAt(i));
      _persist();
    } else if (r == 'saved') {
      setState(() {});
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

  void _showInfoMenu() {
    final t = AppLocalizations.of(context);
    showLLBottomSheet(context, title: t.menu, children: [
      LLSheetTile(
          icon: Icons.info_outline,
          label: t.aboutApp,
          onTap: () {
            Navigator.pop(context);
            _showAbout();
          }),
      LLSheetTile(
          icon: Icons.school_outlined,
          label: t.tutorial,
          onTap: () {
            Navigator.pop(context);
            _showTodo(t.tutorial);
          }),
      LLSheetTile(
          icon: Icons.lightbulb_outline,
          label: t.tips,
          onTap: () {
            Navigator.pop(context);
            _showTodo(t.tips);
          }),
      LLSheetTile(
          icon: Icons.tune,
          label: t.projectSettings,
          onTap: () {
            Navigator.pop(context);
            _openSettings();
          }),
      LLSheetTile(
          icon: Icons.download_outlined,
          label: t.exportData,
          onTap: () {
            Navigator.pop(context);
            _export();
          }),
      LLSheetTile(
          icon: Icons.close,
          label: t.cancel,
          color: AppColors.textSecondary,
          showChevron: false,
          onTap: () => Navigator.pop(context)),
    ]);
  }

  void _showAbout() {
    final t = AppLocalizations.of(context);
    showLLDialog(
      context,
      icon: Icons.travel_explore,
      title: t.aboutApp,
      message: t.aboutBody(kAppVersion),
      primaryLabel: t.ok,
    );
  }

  void _showTodo(String name) => showLLDialog(
        context,
        icon: Icons.construction_outlined,
        title: name,
        message: AppLocalizations.of(context).comingSoon,
        primaryLabel: AppLocalizations.of(context).ok,
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final located = _located;
    final topInset = media.padding.top;
    final collapsedPx = media.size.height * 0.12;

    return Scaffold(
      body: Stack(
        children: [
          // ① 地図主体
          LLMapView(
            controller: _map,
            signs: located,
            schema: widget.schema,
            layer: _layer,
            selected: _selected,
            initialCenter: _center,
            initialZoom: located.isEmpty ? 12 : 16,
            onMapReady: _onMapReady,
            onMarkerTap: (s) {
              setState(() => _selected = s);
              _map.move(LatLng(s.lat!, s.lng!), _map.camera.zoom);
            },
            onMapTap: () => setState(() => _selected = null),
          ),

          // ② 上部ヘッダ
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: LLAppHeader(
                title: 'LLMap',
                trailingIcon: Icons.menu,
                onTrailing: _showInfoMenu,
              ),
            ),
          ),

          // ③ 地図制御層（Map/Satellite ＋ 現在地）
          Positioned(
            top: topInset + 66,
            left: 0,
            right: 0,
            child: Center(
              child: LLSegmentedControl<LLMapLayer>(
                segments: [
                  LLSegment(LLMapLayer.map, t.layerMap),
                  LLSegment(LLMapLayer.satellite, t.layerSatellite),
                ],
                selected: _layer,
                activeColor: _layer == LLMapLayer.satellite
                    ? AppColors.accentViolet
                    : AppColors.accentMustard,
                activeTextColor: _layer == LLMapLayer.satellite
                    ? Colors.white
                    : AppColors.textPrimary,
                onChanged: (v) => setState(() => _layer = v),
              ),
            ),
          ),
          Positioned(
            top: topInset + 66,
            right: AppSpacing.lg,
            child: LLIconButton(
                icon: Icons.my_location,
                tooltip: t.currentLocation,
                onPressed: _locate),
          ),
          if (widget.schema.languageColors.isNotEmpty)
            Positioned(
              top: topInset + 124,
              left: AppSpacing.lg,
              child: LLMapLegend(schema: widget.schema),
            ),

          // ④ 詳情カード（選択時、追加ボタンの上）
          if (_selected != null)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: collapsedPx + 12 + 54 + 10,
              child: LLMapDetailCard(
                sign: _selected!,
                schema: widget.schema,
                onClose: () => setState(() => _selected = null),
              ),
            ),

          // ⑤ 主アクション「新增采集」（記録パネルの上に浮く）
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: collapsedPx + 12,
            child: LLPrimaryButton(
              label: t.newCollection,
              icon: Icons.add_a_photo_outlined,
              onPressed: _startCapture,
            ),
          ),

          // ⑥ 採集記録パネル（常駐ドラッグ抽屉）
          DraggableScrollableSheet(
            minChildSize: 0.12,
            initialChildSize: 0.12,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.12, 0.5, 0.9],
            builder: (ctx, scroll) => _recordsPanel(scroll),
          ),
        ],
      ),
    );
  }

  Widget _recordsPanel(ScrollController scroll) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceIvory,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.floating,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Text(t.recordsTitle, style: AppText.sectionTitle()),
                const SizedBox(width: AppSpacing.sm),
                Text(t.recordsCount(_signs.length), style: AppText.caption()),
                const Spacer(),
                if (_signs.isNotEmpty)
                  IconButton(
                    onPressed: _openGallery,
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                    color: AppColors.accentTerracotta,
                    tooltip: t.archiveTooltip,
                    visualDensity: VisualDensity.compact,
                  ),
                LLTagChip(
                    label: '$_area #$_nextSeq', color: AppColors.accentBlue),
                IconButton(
                  onPressed: _editArea,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: t.areaCodeTooltip,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (_signs.isEmpty)
            _emptyRecords()
          else
            ...List.generate(_signs.length, (i) {
              final s = _signs[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Dismissible(
                  key: ValueKey('${s.id}-$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) => showLLDialog<bool>(
                    context,
                    icon: Icons.delete_outline,
                    iconColor: AppColors.danger,
                    title: t.deleteRecordTitle,
                    message: t.deleteRecordConfirm(s.displayId),
                    primaryLabel: t.delete,
                    onPrimary: () => Navigator.pop(context, true),
                    secondaryLabel: t.cancel,
                    onSecondary: () => Navigator.pop(context, false),
                  ),
                  onDismissed: (_) {
                    setState(() => _signs.removeAt(i));
                    _persist();
                  },
                  child: LLSignCard(
                      sign: s, index: i, onTap: () => _editSign(i)),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _emptyRecords() {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.add_a_photo_outlined,
              size: 40, color: AppColors.accentTerracotta),
          const SizedBox(height: AppSpacing.md),
          Text(t.emptyTitle, style: AppText.sectionTitle()),
          const SizedBox(height: AppSpacing.xs),
          Text(t.emptyBody,
              textAlign: TextAlign.center,
              style: AppText.body().copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
