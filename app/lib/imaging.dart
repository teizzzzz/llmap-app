/// 端末内で完結する画像クロップ・ID採番・CSV生成（backend の exif/storage/csv_io を移植）。
/// PC off でも採集〜書き出しできるようにするための、C 計画のローカル処理層。
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'schema_defaults.dart';

// ── ID 採番（schema.py の photo_id / sign_id を踏襲） ──

/// 写真ID: AREA-YYYYMMDD-NNN （§5.2）
String photoId(String area, String yyyymmdd, int seq) =>
    '${area.toUpperCase()}-$yyyymmdd-${seq.toString().padLeft(3, '0')}';

/// SignID: AREA-SNNN-suffix （§5.4）
String signId(String area, int seq, String suffix) =>
    '${area.toUpperCase()}-S${seq.toString().padLeft(3, '0')}-$suffix';

/// 'YYYY-MM-DD HH:MM:SS' → 'YYYYMMDD'
String yyyymmdd(String captured) {
  if (captured.length >= 10) return captured.substring(0, 10).replaceAll('-', '');
  return '00000000';
}

/// 端末時刻を採集日時 'YYYY-MM-DD HH:MM:SS' に整形。
String nowCaptured() {
  final d = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} '
      '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
}

// ── クロップ（storage.save_crop を踏襲：相対矩形→JPEG q90） ──

/// 全景バイト列から相対矩形 (0..1) を切り出して JPEG bytes を返す。
/// ユーザーが表示画像上で囲んだ座標なので、向き補正せず生バイトのまま切る。
Uint8List cropJpeg(Uint8List src, double x, double y, double w, double h) {
  final image = img.decodeImage(src);
  if (image == null) return src; // デコード不能時は全景をそのまま返す
  final W = image.width, H = image.height;
  final left = (x * W).floor().clamp(0, W);
  final top = (y * H).floor().clamp(0, H);
  final right = ((x + w) * W).floor().clamp(0, W);
  final bottom = ((y + h) * H).floor().clamp(0, H);
  final cw = right - left, ch = bottom - top;
  if (cw < 2 || ch < 2) return src;
  final cropped = img.copyCrop(image, x: left, y: top, width: cw, height: ch);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}

Uint8List _cropEntry(List<dynamic> a) => cropJpeg(
    a[0] as Uint8List, a[1] as double, a[2] as double, a[3] as double, a[4] as double);

/// UI を固めないよう別アイソレートでクロップする。
Future<Uint8List> cropJpegAsync(
        Uint8List src, double x, double y, double w, double h) =>
    compute(_cropEntry, <dynamic>[src, x, y, w, h]);

// ── CSV（csv_io.signs_to_csv を踏襲：標準表頭・utf-8-sig 用に BOM 付与） ──

String _csvField(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// signs を標準表頭の CSV 文字列にする。先頭に BOM（utf-8-sig 相当）。
String signsToCsv(List<Map<String, dynamic>> rows, {List<String>? header}) {
  final cols = header ?? kCsvHeader;
  final buf = StringBuffer('﻿');
  buf.write(cols.map(_csvField).join(','));
  buf.write('\r\n');
  for (final row in rows) {
    buf.write(cols.map((c) => _csvField((row[c] ?? '').toString())).join(','));
    buf.write('\r\n');
  }
  return buf.toString();
}
