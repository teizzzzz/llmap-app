/// Gallery 管理（Step 12 / 12.1）の純ロジック: 筛选・排序・相册归納状態・
/// 安全削除の写真参照計算。UI から切り離し、純 Dart テスト
/// （test/record_ops_test.dart）で検証する。
/// 記録データ・SignID・写真ファイル名は一切変更しない（表示と削除計算のみ）。
library;

import 'albums.dart';
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

// ── AI 下書きの併合（字段定義表 v6 の 2 大規則） ─────────────────────
//
// 規則1: 既存内容は絶対に削除・上書きしない。
//   - 備考: 既存があれば「既存 新規」の形で**後ろに追記**する
//     （定義表 r18「本数据库之前已经有的内容，不要覆盖！」）。
//   - 複数選択字段（主要言語等）: 既存値との**和集合**（新値のみ後ろへ追加）。
//   - 単一選択字段: 既存が非空なら AI 値は書かない（人の入力を守る）。
// 規則2: 不確実は空欄のまま。AI が "" / null を返した字段は一切書かない。

/// AI が返した 1 値を記録へ併合してよい形に整える。null/空白/'—以外の無意味値' を弾く。
String? _cleanAiValue(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return s;
}

/// AI 下書き [draft] を記録 [s] へ併合する。実際に書き込んだ字段数を返す。
/// [multiFields] は「/」併記の複数選択字段（AppSchema.multiFields を渡す）。
/// 既存データは消えない・変わらない（備考は追記、multi は和集合、他は空欄のみ埋める）。
int mergeAiDraft(
  Sign s,
  Map<String, dynamic> draft, {
  required Set<String> multiFields,
}) {
  var changed = 0;
  draft.forEach((field, raw) {
    final value = _cleanAiValue(raw);
    if (value == null) return; // 規則2: 不確実（空）は書かない

    final existing = s.get(field).trim();

    if (field == '備考') {
      // 規則1: 追記のみ。同文が既に含まれていれば重複追記しない。
      if (value == '—') return; // 「無し」相当は備考に書かない
      if (existing.isEmpty) {
        s.set(field, value);
        changed++;
      } else if (!existing.contains(value)) {
        s.set(field, '$existing $value');
        changed++;
      }
      return;
    }

    if (multiFields.contains(field)) {
      // 和集合: 既存の選択値を保ち、新値だけ後ろへ追加（'—' は「無し」マーカー）。
      final current = splitMulti(existing);
      final incoming = splitMulti(value);
      if (current.isEmpty) {
        if (existing.isEmpty) {
          s.set(field, value);
          changed++;
        }
        return;
      }
      final added = incoming.where((v) => !current.contains(v)).toList();
      if (added.isNotEmpty) {
        s.set(field, [...current, ...added].join('/'));
        changed++;
      }
      return;
    }

    // 単一選択・自由記述: 空欄のみ埋める（既存の人力/過去値は上書きしない）。
    if (existing.isEmpty) {
      s.set(field, value);
      changed++;
    }
  });
  return changed;
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

// ── 相册归納状態（Step 12.1） ────────────────────────────────────────

/// Gallery 主視図の归納状態筛选。既定は unfiled（未分類 = 整理待ち Inbox）。
/// 具体的な相册を開いている間は適用しない（相册視図が優先）。
enum AlbumStatusFilter { unfiled, all, filed }

/// 記録がいずれかの相册に所属しているか（= 分類済み）。
bool isFiled(Sign s, List<Album> albums) =>
    albums.any((a) => a.contains(s.id));

/// 归納状態で絞った**新しいリスト**を返す（表示のみ・記録は不変）。
/// 複数相册に所属する記録も filed で 1 回だけ現れる（入力順を保持）。
List<Sign> applyAlbumStatusFilter(
  List<Sign> signs,
  List<Album> albums,
  AlbumStatusFilter status,
) {
  switch (status) {
    case AlbumStatusFilter.all:
      return List<Sign>.of(signs);
    case AlbumStatusFilter.unfiled:
      return signs.where((s) => !isFiled(s, albums)).toList();
    case AlbumStatusFilter.filed:
      return signs.where((s) => isFiled(s, albums)).toList();
  }
}

// ── 導出範囲（Step 14: Selective Export） ────────────────────────────

/// Dataset Package の導出範囲。**導出対象の選択だけ**を変え、導出包の
/// 構造（data.csv / photos / source_photos / metadata / manifest…）は
/// 一切変えない。写真の収束は store.buildBundle が渡された記録から導く。
/// currentAlbum は「いま開いている相册」、album は「導出時に選んだ相册」
/// — 対象の決め方（UI）が違うだけで、抽出規則は同じ。
enum ExportScope { all, currentView, selected, currentAlbum, album, unfiled, filed }

/// 範囲に応じた導出候補を**新しいリスト**で返す（元データは変更しない）。
/// - currentView: Gallery の表示リストをそのまま使う（相册視図・归納状態・
///   筛选・排序を反映済み）。過濾ロジックをここで再実装しない。
/// - selected: 選択集合に一致する記録。順序は allSigns 順で安定させる
///   （筛选変更で表示から外れた選択も含む — ユーザーの選択が正）。
/// - currentAlbum / album: [currentAlbum] の recordIds に対応する記録のみ。
///   既に削除された recordId は解決できないため自然に無視される（崩れない）。
List<Sign> exportCandidates({
  required ExportScope scope,
  required List<Sign> allSigns,
  List<Sign> visible = const [],
  Set<Sign> selected = const {},
  Album? currentAlbum,
  List<Album> albums = const [],
}) {
  switch (scope) {
    case ExportScope.all:
      return List<Sign>.of(allSigns);
    case ExportScope.currentView:
      return List<Sign>.of(visible);
    case ExportScope.selected:
      return allSigns.where(selected.contains).toList();
    case ExportScope.currentAlbum:
    case ExportScope.album:
      final album = currentAlbum;
      if (album == null) return const [];
      return allSigns.where((s) => album.contains(s.id)).toList();
    case ExportScope.unfiled:
      return applyAlbumStatusFilter(allSigns, albums, AlbumStatusFilter.unfiled);
    case ExportScope.filed:
      return applyAlbumStatusFilter(allSigns, albums, AlbumStatusFilter.filed);
  }
}

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
