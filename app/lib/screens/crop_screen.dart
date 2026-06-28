import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
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
  final double? fallbackLat;
  final double? fallbackLng;

  const CropScreen({
    super.key,
    required this.api,
    required this.schema,
    required this.imageBytes,
    required this.fileName,
    required this.area,
    required this.seq,
    this.fallbackLat,
    this.fallbackLng,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  List<CropRegion> _regions = [];
  bool _busy = false;

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      // 框选が無ければ全景1枚として扱う（backend 側でも空なら full 扱い）。
      final signs = await widget.api.extract(
        photoBytes: widget.imageBytes,
        fileName: widget.fileName,
        area: widget.area,
        seq: widget.seq,
        crops: _regions,
        fallbackLat: widget.fallbackLat,
        fallbackLng: widget.fallbackLng,
      );
      if (!mounted) return;
      final result = await Navigator.push<List<Sign>>(
        context,
        MaterialPageRoute(
          builder: (_) => FieldsScreen(
            api: widget.api,
            schema: widget.schema,
            imageBytes: widget.imageBytes,
            fileName: widget.fileName,
            signs: signs,
            regions: _regions,
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
