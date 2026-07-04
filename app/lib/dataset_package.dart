/// LLMap Dataset Package v1.0 の内容生成（純ロジック・File I/O なし）。
///
/// 導出包の構造（docs/data-contract.md §5）:
/// ```text
/// llmap_dataset_YYYYMMDD_HHMMSS.zip
///   data.csv          … 規範化済みレコード（utf-8-sig・標準表頭）
///   photos/           … 裁切図（CSV の 写真ファイル名 と一致）
///   source_photos/    … 元写真（CSV の 元写真ファイル名 と一致・CaptureID 毎に1枚）
///   metadata.json     … 包全体の元情報
///   schema.json       … この CSV が使う字段構成
///   manifest.json     … 全ファイルの機械可読一覧（主フォーマット）
///   MANIFEST.txt      … 人向けの要約（補助）
///   README.md         … 包の説明
/// ```
/// 実際の zip 書き込み・ファイル存在確認は store.buildBundle が行う。
library;

import 'export_normalizer.dart';
import 'models.dart';
import 'schema_defaults.dart';
import 'version.dart';

/// Dataset Package フォーマット版。包構造を変えたら上げる。
const String kDatasetFormat = 'LLMap Dataset Package';
const String kDatasetFormatVersion = '1.0';

/// 写真の zip 内パス（crop → photos/、source → source_photos/）。
String zipPathFor(ExportPhoto p) =>
    p.type == 'source' ? 'source_photos/${p.zipName}' : 'photos/${p.zipName}';

/// 導出包のファイル名: llmap_dataset_YYYYMMDD_HHMMSS.zip。
String datasetFileName(DateTime t) {
  String p(int n) => n.toString().padLeft(2, '0');
  return 'llmap_dataset_${t.year}${p(t.month)}${p(t.day)}'
      '_${p(t.hour)}${p(t.minute)}${p(t.second)}.zip';
}

/// タイムゾーン付き ISO8601（Dart の toIso8601String はローカル時刻に
/// オフセットを付けないため自前で付与する）。
String iso8601WithOffset(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  final o = d.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final abs = o.abs();
  return '${d.year}-${p(d.month)}-${p(d.day)}'
      'T${p(d.hour)}:${p(d.minute)}:${p(d.second)}'
      '$sign${p(abs.inHours)}:${p(abs.inMinutes % 60)}';
}

/// 写真1枚の存在確認結果（store 側で File を調べて渡す）。
class PhotoStat {
  final ExportPhoto photo;
  final bool exists;
  final int sizeBytes;
  const PhotoStat(this.photo, {required this.exists, this.sizeBytes = 0});
}

/// metadata.json の内容。件数は規範化済み rows（= data.csv の行）で数える。
Map<String, Object> buildMetadataJson({
  required int recordCount,
  required List<PhotoStat> stats,
  required NormalizedExport norm,
  required DateTime exportedAt,
}) {
  int count(String type, bool exists) => stats
      .where((s) => s.photo.type == type && s.exists == exists)
      .length;
  // EntryMode / DataStatus の分布（空値=旧データは unknown に集計し、
  // 合計が recordCount と一致するようにする）。
  Map<String, int> tally(String key) {
    final m = <String, int>{};
    for (final row in norm.rows) {
      final v = (row[key] ?? '').toString();
      final k = v.isEmpty ? 'unknown' : v;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  return {
    'format': kDatasetFormat,
    'formatVersion': kDatasetFormatVersion,
    'exportedAt': iso8601WithOffset(exportedAt),
    'appVersion': kAppVersion,
    'schemaVersion': kSchemaVersion,
    'recordCount': recordCount,
    'photoCount': count('crop', true),
    'sourcePhotoCount': count('source', true),
    'normalizedLegacyRecordCount': norm.normalizedLegacy.length,
    'missingPhotoCount': count('crop', false),
    // 元写真が包に無い数 = 参照先ファイル欠落 ＋ そもそも元写真を持たない記録。
    'missingSourcePhotoCount': count('source', false) + norm.sourceMissing.length,
    'entryModeCounts': tally('EntryMode'),
    'dataStatusCounts': tally('DataStatus'),
  };
}

/// schema.json の内容（Console が CSV の字段構成を解釈するための情報）。
Map<String, Object> buildSchemaJson(AppSchema schema) => {
      'schemaVersion': kSchemaVersion,
      'headers': schema.csvHeader,
      'systemFields': AppSchema.systemFields.toList(),
      // 標準モードの簡易表単が扱う字段（Console が採集モード別の表示に使える）。
      'standardDefaultFields': kStandardDefaultFields,
      'standardMoreFields': kStandardMoreFields,
      'fieldGroups': kFieldGroups,
      'statusValues': schema.statusValues,
      'dataStatusMap': kDataStatusMap,
      'multiFields': schema.multiFields.toList(),
      'enums': schema.enums,
    };

/// manifest.json の内容（包内ファイルの機械可読一覧・主フォーマット）。
Map<String, Object> buildManifestJson(
    List<PhotoStat> stats, NormalizedExport norm) {
  Map<String, Object> entry(PhotoStat s) => {
        'path': zipPathFor(s.photo),
        'type': s.photo.type,
        if (s.photo.signId.isNotEmpty) 'signId': s.photo.signId,
        'captureId': s.photo.captureId,
        'exists': s.exists,
        if (s.exists) 'sizeBytes': s.sizeBytes,
        // 規範化で改名した場合の本地旧名（追跡用）。
        if (s.photo.localName != s.photo.zipName)
          'localName': s.photo.localName,
      };
  return {
    'formatVersion': kDatasetFormatVersion,
    'files': [for (final s in stats.where((s) => s.exists)) entry(s)],
    'missingFiles': [for (final s in stats.where((s) => !s.exists)) entry(s)],
    'sourceMissing': norm.sourceMissing,
    'normalizedLegacyRecords': norm.normalizedLegacy,
  };
}

/// MANIFEST.txt（人向けの要約。主フォーマットは manifest.json）。
String buildManifestTxt(
    int recordCount, List<PhotoStat> stats, NormalizedExport norm) {
  final missing = stats.where((s) => !s.exists).toList();
  final buf = StringBuffer()
    ..writeln('records: $recordCount')
    ..writeln('photos_included: ${stats.where((s) => s.exists).length}')
    ..writeln('photos_missing: ${missing.length}');
  for (final s in missing) {
    buf.writeln('  - ${zipPathFor(s.photo)} (local: ${s.photo.localName})');
  }
  buf.writeln('source_missing: ${norm.sourceMissing.length}');
  for (final id in norm.sourceMissing) {
    buf.writeln('  - $id');
  }
  buf.writeln('normalized_legacy_records: ${norm.normalizedLegacy.length}');
  return buf.toString();
}

/// 包内 README.md。
String buildReadme() => '''
# LLMap Dataset Package

言語景観採集アプリ **LLMap Mobile** が書き出した標準データ包です。
将来の **LLMap Research Console**（PC/Web 研究管理台）にそのまま取り込める
交換フォーマット（$kDatasetFormat v$kDatasetFormatVersion）として設計されています。

## 構造

| パス | 内容 |
|---|---|
| `data.csv` | 全採集レコード（utf-8-sig）。1行 = 1 sign。列構成は `schema.json` 参照 |
| `photos/` | 各 sign の裁切図。ファイル名は `data.csv` の `写真ファイル名` と一致 |
| `source_photos/` | 原始完整写真（元写真）。`元写真ファイル名` と一致し、同一 CaptureID の sign 群が1枚を共有 |
| `metadata.json` | この包の元情報（導出日時・件数・アプリ/契約バージョン） |
| `schema.json` | `data.csv` の字段構成（表頭・システム字段・分组・選択肢） |
| `manifest.json` | 包内全ファイルの機械可読一覧（欠落・規範化の記録を含む**主フォーマット**） |
| `MANIFEST.txt` | 人向けの要約（補助） |

## 旧データについて

旧バージョンの記録は**導出時に**新データ契約（CaptureID 中心の命名）へ規範化されます。
- 包内の写真は `AREA-legacy-…` 形式の新名で複製されています。
- **本地（端末内）の元データ・写真ファイルは一切変更されていません。**
- 規範化された記録の対応表は `manifest.json` の `normalizedLegacyRecords`、
  元写真が存在しない記録は `sourceMissing` にあります。

詳細仕様: リポジトリの `docs/data-contract.md`
''';
