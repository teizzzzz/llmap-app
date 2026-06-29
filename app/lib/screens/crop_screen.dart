import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../capture.dart';
import '../imaging.dart';
import '../models.dart';
import '../settings.dart';
import '../store.dart';
import '../widgets/box_selector.dart';
import 'fields_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _gpsFuture = currentGps();
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      final gps = await _gpsFuture;
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
        title: Text('框选  (${_regions.length} sign)'),
        actions: [
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: '最後の枠を削除',
              onPressed: () => setState(() => _regions.removeLast()),
              icon: const Icon(Icons.undo),
            ),
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: '全消去',
              onPressed: () => setState(() => _regions = []),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFece7df),
            padding: const EdgeInsets.all(8),
            child: Text(
              _regions.isEmpty
                  ? 'ドラッグで景観を囲む。囲まなければ全景1枚として登録。'
                  : '枠: ${_regions.map((r) => r.suffix).join(", ")}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BoxSelector(
                imageBytes: widget.imageBytes,
                regions: _regions,
                onChanged: (r) => setState(() => _regions = r),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _next,
        icon: _busy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward),
        label: Text(_regions.isEmpty ? '全景で次へ' : '字段入力へ'),
      ),
    );
  }
}
