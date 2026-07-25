/// 端末内で完結する画像クロップ・ID採番・CSV生成（backend の exif/storage/csv_io を移植）。
/// PC off でも採集〜書き出しできるようにするための、C 計画のローカル処理層。
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'schema_defaults.dart';

// ── ID 採番（新契約: CaptureID を一意性の中心にする。docs/data-contract.md 参照） ──
//
// CaptureID   = AREA-COLLECTORID-YYMMDDHHMMSSmmm   … 1回の撮影イベントの一意ID
// SignID      = CaptureID-suffix
// 写真ファイル名   = CaptureID-<suffix>.jpg
// 元写真ファイル名 = CaptureID-source.jpg
// DisplayID   = AREA-YYYYMMDD-SEQ-suffix           … 表示専用（主キーにしない）
//
// 採集者ID＋ミリ秒時刻を含むため、複数人が同日同地区で採集しても衝突しない。

/// CaptureID: AREA-COLLECTORID-YYMMDDHHMMSSmmm。1回の撮影イベントの一意ID。
/// collectorId が空（想定外）でも時刻部で一意性を保つ。
String makeCaptureId(String area, String collectorId, DateTime capturedAt) {
  final a = area.toUpperCase();
  final c = collectorId.trim();
  final head = c.isEmpty ? a : '$a-$c';
  return '$head-${_timestampMs(capturedAt)}';
}

/// SignID: CaptureID-suffix。同一写真内の各 sign を識別する。
String makeSignId(String captureId, String suffix) => '$captureId-$suffix';

/// DisplayID: AREA-YYYYMMDD-SEQ-suffix。人が読む表示専用ID（一意性は担わない）。
String makeDisplayId(String area, DateTime capturedAt, int seq, String suffix) {
  String p(int n) => n.toString().padLeft(2, '0');
  final d = '${capturedAt.year}${p(capturedAt.month)}${p(capturedAt.day)}';
  return '${area.toUpperCase()}-$d-${seq.toString().padLeft(3, '0')}-$suffix';
}

/// 元写真（原始完整写真）のファイル名: CaptureID-source.jpg。
String sourcePhotoName(String captureId) => '$captureId-source.jpg';

/// 裁切写真のファイル名: `CaptureID-<suffix>.jpg`。
String cropPhotoName(String captureId, String suffix) =>
    '$captureId-$suffix.jpg';

/// 'YYMMDDHHMMSSmmm'（ミリ秒15桁）。CaptureID の時刻部。
String _timestampMs(DateTime t) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(t.year % 100)}${p(t.month)}${p(t.day)}'
      '${p(t.hour)}${p(t.minute)}${p(t.second)}'
      '${t.millisecond.toString().padLeft(3, '0')}';
}

/// DateTime を採集日時 'YYYY-MM-DD HH:MM:SS' に整形。
String formatCaptured(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} '
      '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
}

// ── 旧ID採番（legacy）。旧データの解釈用に保持。新規採番には使わない ──

/// [legacy] 写真ID: AREA-YYYYMMDD-NNN。新規レコードでは 写真ID=CaptureID。
String photoId(String area, String yyyymmdd, int seq) =>
    '${area.toUpperCase()}-$yyyymmdd-${seq.toString().padLeft(3, '0')}';

/// [legacy] SignID: 地点-採集者-序号（例 OOK-K7m9Qp4t-S001-a）。
/// 新規レコードは makeSignId(makeCaptureId(...), suffix) を使う。
String signId(String area, int seq, String suffix, {String collector = ''}) {
  final a = area.toUpperCase();
  final s = seq.toString().padLeft(3, '0');
  final c = collector.trim();
  return c.isEmpty ? '$a-S$s-$suffix' : '$a-$c-S$s-$suffix';
}

/// 'YYYY-MM-DD HH:MM:SS' → 'YYYYMMDD'
String yyyymmdd(String captured) {
  if (captured.length >= 10) return captured.substring(0, 10).replaceAll('-', '');
  return '00000000';
}

/// 端末時刻を採集日時 'YYYY-MM-DD HH:MM:SS' に整形。
String nowCaptured() => formatCaptured(DateTime.now());

// ── クロップ（storage.save_crop を踏襲：相対矩形→JPEG q90） ──

/// 全景バイト列から相対矩形 (0..1) を切り出して JPEG bytes を返す。
/// 框选座標は「画面に表示された向き」基準。Flutter の表示は EXIF Orientation を
/// 適用するが、image パッケージの decode は生ピクセルのままなので、切り出し前に
/// bakeOrientation で向きをピクセルへ焼き込み、表示と座標系を一致させる
/// （EXIF 付き縦位置写真で框选が 90° ずれるのを防ぐ。Orientation=1 は実質無変換）。
Uint8List cropJpeg(Uint8List src, double x, double y, double w, double h) {
  final decoded = img.decodeImage(src);
  if (decoded == null) return src; // デコード不能時は全景をそのまま返す
  final image = img.bakeOrientation(decoded);
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
