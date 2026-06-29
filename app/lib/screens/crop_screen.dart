import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../capture.dart';
import '../imaging.dart';
import '../models.dart';
import '../settings.dart';
import '../store.dart';
import '../theme/tokens.dart';
import '../widgets/box_selector.dart';
import '../widgets/ll/ll.dart';
import 'fields_screen.dart';
import 'select_location_screen.dart';

/// 框选画面：1枚の写真から複数 sign を矩形で切り出す（②）。
/// 「完了」で backend /extract を呼び、字段入力画面へ。
class CropScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  final Uint8List imageBytes;
  final String fileName;
  final String area;
  final int seq;
  final AiConfig aiConfig;

  const CropScreen({
    super.key,
    required this.api,
    required this.schema,
    required this.imageBytes,
    required this.fileName,
    required this.area,
    required this.seq,
    required this.aiConfig,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  List<CropRegion> _regions = [];
  bool _busy = false;
  // 撮影時GPSを画面表示中に非ブロッキングで取得（EXIF無し時の fallback）。
  Future<({double lat, double lng})?>? _gpsFuture;
  // 手動微調整した位置（あれば自動GPSより優先）。
  ({double lat, double lng})? _manualGps;

  @override
  void initState() {
    super.initState();
    _gpsFuture = currentGps();
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      // 手動調整があれば優先、無ければ自動GPS。
      final gps = _manualGps ?? await _gpsFuture;
      // 端末内で sign 群を生成し、写真を端末に保存する（後端非依存／PC off 可）。
      final signs = await _extractLocal(gps);
      if (!mounted) return;
      final result = await Navigator.push<List<Sign>>(
        context,
        MaterialPageRoute(
          builder: (_) => FieldsScreen(
            schema: widget.schema,
            imageBytes: widget.imageBytes,
            signs: signs,
            regions: _regions,
            aiConfig: widget.aiConfig,
          ),
        ),
      );
      if (result != null && mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('字段处理失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 後端 /extract のローカル版：写真を端末保存し sign 群を組み立てる。
  Future<List<Sign>> _extractLocal(({double lat, double lng})? gps) async {
    final captured = nowCaptured();
    final pid = photoId(widget.area, yyyymmdd(captured), widget.seq);
    final panoName = '$pid.jpg';
    await LocalStore.instance.savePhoto(panoName, widget.imageBytes);

    // 框选が無ければ全景1枚を1 sign として扱う。
    final regions = _regions.isEmpty
        ? [CropRegion(suffix: 'a', x: 0, y: 0, w: 1, h: 1)]
        : _regions;

    final signs = <Sign>[];
    for (final r in regions) {
      final isFull = r.w >= 0.999 && r.h >= 0.999;
      String fname;
      if (isFull) {
        fname = panoName;
      } else {
        final cropped =
            await cropJpegAsync(widget.imageBytes, r.x, r.y, r.w, r.h);
        fname = '$pid-${r.suffix}.jpg';
        await LocalStore.instance.savePhoto(fname, cropped);
      }
      signs.add(Sign({
        'SignID': signId(widget.area, widget.seq, r.suffix),
        '_status': 'pending',
        '写真ID': pid,
        '写真ファイル名': fname,
        '全景写真ファイル名': isFull ? '' : panoName,
        '緯度': gps?.lat,
        '経度': gps?.lng,
        '採集日時': captured,
      }));
    }
    return signs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('框选标志  (${_regions.length})'),
        actions: [
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: '撤销最后一个框',
              onPressed: () => setState(() => _regions.removeLast()),
              icon: const Icon(Icons.undo),
            ),
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: '清空',
              onPressed: () => setState(() => _regions = []),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          // 操作ヒント＋GPS状態
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: LLCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.crop_free,
                      size: 18, color: AppColors.accentTerracotta),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _regions.isEmpty
                          ? '拖动框选每个标志；不框选则整张作为一条记录。'
                          : '已框选：${_regions.map((r) => r.suffix).join("、")}',
                      style: AppText.caption(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _gpsStatus(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: BoxSelector(
                imageBytes: widget.imageBytes,
                regions: _regions,
                onChanged: (r) => setState(() => _regions = r),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LLPrimaryButton(
            label: _regions.isEmpty ? '整张作为一条记录 · 下一步' : '下一步：填写字段',
            icon: Icons.arrow_forward,
            busy: _busy,
            onPressed: _busy ? null : _next,
          ),
        ),
      ),
    );
  }

  /// GPS 状態＋手動調整入口（自動GPS後の任意修正）。
  Widget _gpsStatus() {
    Widget row(IconData icon, String text, Color color, String action) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, 0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text, style: AppText.caption().copyWith(color: color)),
            const Spacer(),
            TextButton(
              onPressed: _adjustLocation,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(action, style: AppText.caption()
                  .copyWith(color: AppColors.accentBlue)),
            ),
          ],
        ),
      );
    }

    if (_manualGps != null) {
      return row(Icons.edit_location_alt, '已手动调整位置',
          AppColors.accentBlue, '重新调整');
    }
    return FutureBuilder<({double lat, double lng})?>(
      future: _gpsFuture,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final (icon, text, color) = waiting
            ? (Icons.gps_not_fixed, '正在获取当前位置…', AppColors.textSecondary)
            : snap.data != null
                ? (Icons.gps_fixed, '已获取当前位置', AppColors.success)
                : (Icons.gps_off, '无法获取当前位置，请手动选择拍摄地点',
                    AppColors.warning);
        return row(icon, text, color,
            snap.data != null ? '位置不准确？手动调整' : '手动选择');
      },
    );
  }

  /// Select Location 画面で位置を手動微調整し、結果を _manualGps に反映。
  Future<void> _adjustLocation() async {
    final base = _manualGps ?? await _gpsFuture;
    if (!mounted) return;
    final r = await Navigator.push<({double lat, double lng})>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          initial: base == null ? null : (lat: base.lat, lng: base.lng),
        ),
      ),
    );
    if (r != null && mounted) setState(() => _manualGps = r);
  }
}
