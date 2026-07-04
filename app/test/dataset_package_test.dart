import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/dataset_package.dart';
import 'package:llmap_app/export_normalizer.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/schema_defaults.dart';

void main() {
  // 新1件（source あり）＋ 旧1件（整図・source なし）の典型ミックス。
  final signs = [
    Sign({
      'SignID': 'OOK-7Kx9Qp2A-260701143512482-a',
      '_status': 'pending',
      'CaptureID': 'OOK-7Kx9Qp2A-260701143512482',
      '写真ファイル名': 'OOK-7Kx9Qp2A-260701143512482-a.jpg',
      '元写真ファイル名': 'OOK-7Kx9Qp2A-260701143512482-source.jpg',
    }),
    Sign({
      'SignID': 'OOK-S010-a',
      '_status': 'ai',
      '写真ID': 'OOK-20260701-010',
      '写真ファイル名': 'OOK-20260701-010.jpg',
      '全景写真ファイル名': '',
      '採集日時': '2026-07-01 15:00:00',
    }),
  ];
  final norm = normalizeForExport(signs);
  // store 側の存在確認を模擬: 新レコードの source だけ欠落しているとする。
  final stats = [
    for (final p in norm.photos)
      PhotoStat(p,
          exists: p.type == 'crop', sizeBytes: p.type == 'crop' ? 1000 : 0),
  ];
  final exportedAt = DateTime(2026, 7, 5, 12, 34, 56);

  test('zipPathFor: crop は photos/、source は source_photos/', () {
    final crop = norm.photos.firstWhere((p) => p.type == 'crop');
    final src = norm.photos.firstWhere((p) => p.type == 'source');
    expect(zipPathFor(crop), startsWith('photos/'));
    expect(zipPathFor(src), startsWith('source_photos/'));
  });

  test('datasetFileName は llmap_dataset_YYYYMMDD_HHMMSS.zip', () {
    expect(datasetFileName(exportedAt), 'llmap_dataset_20260705_123456.zip');
  });

  test('metadata.json: 件数・欠落数が一致する', () {
    final m = buildMetadataJson(
        recordCount: 2, stats: stats, norm: norm, exportedAt: exportedAt);
    expect(m['format'], 'LLMap Dataset Package');
    expect(m['formatVersion'], '1.0');
    expect(m['schemaVersion'], kSchemaVersion);
    expect(m['recordCount'], 2);
    expect(m['photoCount'], 2); // 裁切2枚は存在
    expect(m['sourcePhotoCount'], 0); // source は欠落と設定
    expect(m['normalizedLegacyRecordCount'], 1);
    expect(m['missingPhotoCount'], 0);
    // 新レコードの source 欠落(1) + 旧・整図の source なし(1)。
    expect(m['missingSourcePhotoCount'], 2);
    expect(m['exportedAt'], startsWith('2026-07-05T12:34:56'));
  });

  test('schema.json: 表頭・システム字段・分组が入る', () {
    final s = buildSchemaJson(defaultSchema());
    expect(s['headers'], kCsvHeader);
    expect(s['systemFields'], AppSchema.systemFields.toList());
    expect((s['fieldGroups'] as List).length, 5);
    // 分组の字段合計 = 表頭の字段数（漏れなし）。
    final grouped = (s['fieldGroups'] as List)
        .expand((g) => (g as Map)['fields'] as List)
        .toSet();
    expect(grouped, kCsvHeader.toSet());
  });

  test('manifest.json: files/missingFiles/sourceMissing/normalizedLegacy', () {
    final m = buildManifestJson(stats, norm);
    final files = m['files'] as List;
    final missing = m['missingFiles'] as List;
    expect(files.length, 2);
    expect(missing.length, 1); // 新レコードの source のみ参照先欠落
    expect((missing.single as Map)['type'], 'source');
    // 旧レコードの crop はリネームされ localName が残る。
    final legacyCrop = files
        .cast<Map>()
        .firstWhere((f) => (f['path'] as String).contains('legacy'));
    expect(legacyCrop['localName'], 'OOK-20260701-010.jpg');
    expect(legacyCrop['signId'], isNotEmpty);
    // 旧・整図は source を持たない → sourceMissing。
    expect((m['sourceMissing'] as List).single, contains('legacy'));
    final nl = (m['normalizedLegacyRecords'] as List).single as Map;
    expect(nl['legacySignId'], 'OOK-S010-a');
  });

  test('README / MANIFEST.txt が生成される', () {
    expect(buildReadme(), contains('LLMap Dataset Package'));
    final txt = buildManifestTxt(2, stats, norm);
    expect(txt, contains('records: 2'));
    expect(txt, contains('source_missing: 1'));
  });
}
