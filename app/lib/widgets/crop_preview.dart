/// 框选した矩形領域だけを表示するプレビュー。
/// 元画像を再エンコードせず drawImageRect で該当部分を描く。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';

class CropPreview extends StatefulWidget {
  final Uint8List imageBytes;
  final CropRegion? region; // null は全景
  final double height;
  const CropPreview({
    super.key,
    required this.imageBytes,
    required this.region,
    this.height = 200,
  });

  @override
  State<CropPreview> createState() => _CropPreviewState();
}

class _CropPreviewState extends State<CropPreview> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.imageBytes).then((img) {
      if (mounted) setState(() => _img = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFece7df),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: img == null
          ? const Center(child: CircularProgressIndicator())
          : CustomPaint(
              painter: _CropPainter(img, widget.region),
              size: Size.infinite,
            ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image img;
  final CropRegion? region;
  _CropPainter(this.img, this.region);

  @override
  void paint(Canvas canvas, Size size) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final r = region;
    final src = r == null
        ? Rect.fromLTWH(0, 0, iw, ih)
        : Rect.fromLTWH(r.x * iw, r.y * ih, r.w * iw, r.h * ih);

    // src を size に contain で収める
    final scale =
        (size.width / src.width).clamp(0.0, double.infinity) <
                (size.height / src.height)
            ? size.width / src.width
            : size.height / src.height;
    final dw = src.width * scale, dh = src.height * scale;
    final dst = Rect.fromLTWH(
        (size.width - dw) / 2, (size.height - dh) / 2, dw, dh);

    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.img != img || old.region != region;
}
