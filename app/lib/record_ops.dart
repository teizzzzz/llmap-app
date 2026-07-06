/// Gallery 管理（Step 12）の純ロジック: 筛选・排序・安全削除の写真参照計算。
/// UI から切り離し、純 Dart テスト（test/record_ops_test.dart）で検証する。
/// 記録データ・SignID・写真ファイル名は一切変更しない（表示と削除計算のみ）。
library;

import 'models.dart';

// ── 写真参照（安全削除） ──────────────────────────────────────────────

/// 1つの記録が参照する写真ファイル名をすべて返す
/// （裁切写真・元写真・旧字段の全景写真）。空と「—」は除外。
Set<String> photoRefsOf(Sign s) {
  final refs = <String>{};
  for (final key in const ['写真ファイル名', '元写真ファイル名', '全景写真ファイル名']) {
    final v = s.get(key);
    if (v.isNotEmpty && v != '—') refs.add(v);
  }
  return refs;
}

/// [deleting] を削除した後に**安全に消せる**写真ファイル名を返す。
/// = 削除対象が参照し、かつ残る記録のどれからも参照されないもの。
/// 1枚の元写真を複数 sign が共有するケース（1图多sign）で、
/// まだ使われている元写真を誤って消さないための計算。
Set<String> orphanedPhotos({
  required Iterable<Sign> deleting,
  required Iterable<Sign> remaining,
}) {
  final deleted = <String>{};
  for (final s in deleting) {
    deleted.addAll(photoRefsOf(s));
  }
  final kept = <String>{};
  for (final s in remaining) {
    kept.addAll(photoRefsOf(s));
  }
  return deleted.difference(kept);
}

// ── 排序 ─────────────────────────────────────────────────────────────

enum GallerySort { newestFirst, oldestFirst, displayIdAsc, displayIdDesc }

/// 採集日時（'YYYY-MM-DD HH:MM:SS'）を DateTime に。解析不能は null。
DateTime? capturedAtOf(Sign s) {
  final v = s.get('採集日時').trim();
  if (v.isEmpty || v == '—') return null;
  return DateTime.tryParse(v.replaceFirst(' ', 'T'));
}

/// 表示用に並べ替えた**新しいリスト**を返す（元リストは変更しない）。
/// 採集日時が無い/壊れている旧データは、日時ソートでは常に末尾へ。
List<Sign> sortedSigns(List<Sign> signs, GallerySort sort) {
  final list = List<Sign>.of(signs);
  int byDate(Sign a, Sign b, {required bool newestFirst}) {
    final da = capturedAtOf(a);
    final db = capturedAtOf(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1; // 解析不能 → 末尾
    if (db == null) return -1;
    return newestFirst ? db.compareTo(da) : da.compareTo(db);
  }

  switch (sort) {
    case GallerySort.newestFirst:
      list.sort((a, b) => byDate(a, b, newestFirst: true));
    case GallerySort.oldestFirst:
      list.sort((a, b) => byDate(a, b, newestFirst: false));
    case GallerySort.displayIdAsc:
      list.sort((a, b) => a.displayId.compareTo(b.displayId));
    case GallerySort.displayIdDesc:
      list.sort((a, b) => b.displayId.compareTo(a.displayId));
  }
  return list;
}

// ── 筛选 ─────────────────────────────────────────────────────────────

/// DataStatus の実効値。旧データで DataStatus 未併記なら _status から導出。
String effectiveDataStatus(Sign s) {
  final v = s.get('DataStatus');
  return v.isNotEmpty ? v : dataStatusFor(s.status);
}

/// Gallery の表示筛选。**表示のみ**に作用し、記録本体は変更しない。
/// null の条件は「すべて」。
class GalleryFilter {
  String? language; // 主要言語（併記は splitMulti で個別値に展開して照合）
  String? source; // 設置主体（旧 Gallery 筛选の互換）
  String? entryMode; // 内部値 quick/standard/research
  String? dataStatus; // 内部値 raw/submitted/ai_drafted/...
  String? areaCode;
  String? collectorId;
  bool? hasGps;
  bool? hasPhoto; // 裁切写真参照の有無
  bool? hasSource; // 元写真参照の有無

  GalleryFilter();

  List<Object?> get _values => [
        language, source, entryMode, dataStatus, areaCode, collectorId,
        hasGps, hasPhoto, hasSource,
      ];

  int get activeCount => _values.where((v) => v != null).length;
  bool get isActive => activeCount > 0;

  void clear() {
    language = null;
    source = null;
    entryMode = null;
    dataStatus = null;
    areaCode = null;
    collectorId = null;
    hasGps = null;
    hasPhoto = null;
    hasSource = null;
  }

  bool matches(Sign s) {
    if (language != null && !splitMulti(s.get('主要言語')).contains(language)) {
      return false;
    }
    if (source != null && s.get('設置主体') != source) return false;
    if (entryMode != null && s.get('EntryMode') != entryMode) return false;
    if (dataStatus != null && effectiveDataStatus(s) != dataStatus) return false;
    if (areaCode != null && s.get('地区コード') != areaCode) return false;
    if (collectorId != null && s.get('採集者ID') != collectorId) return false;
    if (hasGps != null && (s.lat != null && s.lng != null) != hasGps) {
      return false;
    }
    if (hasPhoto != null && s.fileName.isNotEmpty != hasPhoto) return false;
    if (hasSource != null && s.sourceFileName.isNotEmpty != hasSource) {
      return false;
    }
    return true;
  }
}
