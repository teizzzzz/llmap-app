/// 框选ウィジェット：画像上をドラッグして複数の矩形(sign)を引く。
/// 各矩形は 0..1 の相対座標で保持し、1枚に複数 = 1图多个sign。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/tokens.dart';

class BoxSelector extends StatefulWidget {
  final Uint8List imageBytes;
  final List<CropRegion> regions;
  final ValueChanged<List<CropRegion>> onChanged;

  const BoxSelector({
    super.key,
    required this.imageBytes,
    required this.regions,
    required this.onChanged,
  });

  @override
  State<BoxSelector> createState() => _BoxSelectorState();
}

class _BoxSelectorState extends State<BoxSelector> {
  ui.Image? _img;
  Offset? _start;
  Offset? _current;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final img = await decodeImageFromList(widget.imageBytes);
    if (mounted) setState(() => _img = img);
  }

  /// i 番目の suffix: a..z, aa..zz（SignID の一部になるため必ず一意にする）。
  static String _suffixAt(int i) {
    if (i < 26) return String.fromCharCode(97 + i);
    final j = i - 26;
    return '${String.fromCharCode(97 + j ~/ 26)}${String.fromCharCode(97 + j % 26)}';
  }

  String _nextSuffix() {
    // 既存に無い最小のものを採用（26 個を超えても重複させない）。
    final used = widget.regions.map((r) => r.suffix).toSet();
    for (var i = 0; i < 26 + 26 * 26; i++) {
      final s = _suffixAt(i);
      if (!used.contains(s)) return s;
    }
    return 'x${widget.regions.length + 1}'; // 理論上到達しない安全弁
  }

  void _commit(Size box) {
    if (_start == null || _current == null) return;
    final a = _start!, b = _current!;
    final x0 = (a.dx < b.dx ? a.dx : b.dx) / box.width;
    final y0 = (a.dy < b.dy ? a.dy : b.dy) / box.height;
    final w = (a.dx - b.dx).abs() / box.width;
    final h = (a.dy - b.dy).abs() / box.height;
    _start = null;
    _current = null;
    if (w < 0.02 || h < 0.02) {
      setState(() {}); // 小さすぎる枠は破棄
      return;
    }
    final next = [
      ...widget.regions,
      CropRegion(
        suffix: _nextSuffix(),
        x: x0.clamp(0, 1),
        y: y0.clamp(0, 1),
        w: w.clamp(0, 1),
        h: h.clamp(0, 1),
      ),
    ];
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: img.width / img.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onPanStart: (d) => setState(() {
                _start = d.localPosition;
                _current = d.localPosition;
              }),
              onPanUpdate: (d) => setState(() => _current = d.localPosition),
              onPanEnd: (_) => _commit(box),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(widget.imageBytes, fit: BoxFit.fill),
                  CustomPaint(
                    painter: _BoxPainter(
                      regions: widget.regions,
                      dragStart: _start,
                      dragCurrent: _current,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final List<CropRegion> regions;
  final Offset? dragStart;
  final Offset? dragCurrent;

  _BoxPainter({
    required this.regions,
    this.dragStart,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accentTerracotta;
    final fill = Paint()
      ..color = AppColors.accentTerracotta.withValues(alpha: 0.13);

    for (final r in regions) {
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.w * size.width,
        r.h * size.height,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
      final tp = TextPainter(
        text: TextSpan(
          text: r.suffix,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: AppColors.accentTerracotta,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + const Offset(2, 2));
    }

    if (dragStart != null && dragCurrent != null) {
      final live = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.success;
      canvas.drawRect(Rect.fromPoints(dragStart!, dragCurrent!), live);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => true;
}
