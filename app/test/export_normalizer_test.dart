import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/export_normalizer.dart';
import 'package:llmap_app/models.dart';

void main() {
  group('normalizeForExport: 旧レコードの規範化', () {
    Sign legacy(String suffix) => Sign({
          'SignID': 'OOK-S008-$suffix',
          '_status': 'ai',
          '写真ID': 'OOK-20260701-008',
          '写真ファイル名': 'OOK-20260701-008-$suffix.jpg',
          '全景写真ファイル名': 'OOK-20260701-008.jpg',
          '緯度': 35.6,
          '経度': 139.7,
          '採集日時': '2026-07-01 14:35:12',
        });

    test('CaptureID は AREA-legacy-秒精度+000 で生成される', () {
      final r = normalizeForExport([legacy('a')]);
      expect(r.rows.single['CaptureID'], 'OOK-legacy-260701143512000');
      expect(r.rows.single['SignID'], 'OOK-legacy-260701143512000-a');
      expect(r.rows.single['採集者ID'], 'legacy');
      expect(r.rows.single['地区コード'], 'OOK');
      expect(r.rows.single['LocalSeq'], 8);
      expect(r.rows.single['CropSuffix'], 'a');
      expect(r.rows.single['CropRect'], '{"x":0,"y":0,"w":1,"h":1}');
      expect(r.rows.single['DisplayID'], 'OOK-S008-a'); // 旧 SignID を継承
      expect(r.rows.single['DataStatus'], 'ai_drafted');
      // 写真ID は本地追跡用に旧値のまま。
      expect(r.rows.single['写真ID'], 'OOK-20260701-008');
    });

    test('同一 写真ID の裁切群は同じ CaptureID・元写真を共有する', () {
      final r = normalizeForExport([legacy('a'), legacy('b')]);
      expect(r.rows[0]['CaptureID'], r.rows[1]['CaptureID']);
      expect(r.rows[0]['SignID'], isNot(r.rows[1]['SignID']));
      expect(r.rows[0]['元写真ファイル名'], r.rows[1]['元写真ファイル名']);
      expect(r.rows[0]['元写真ファイル名'], 'OOK-legacy-260701143512000-source.jpg');
      // 写真: source 1枚 + 裁切2枚。zip名 → 本地旧名の写像。
      expect(r.photos.length, 3);
      final map = {for (final p in r.photos) p.zipName: p.localName};
      expect(map['OOK-legacy-260701143512000-a.jpg'], 'OOK-20260701-008-a.jpg');
      expect(map['OOK-legacy-260701143512000-b.jpg'], 'OOK-20260701-008-b.jpg');
      expect(map['OOK-legacy-260701143512000-source.jpg'], 'OOK-20260701-008.jpg');
      expect(r.sourceMissing, isEmpty);
    });

    test('別撮影イベントが同秒なら CaptureID に -002 を追加（静默上書きしない）', () {
      final other = legacy('a')
        ..data['写真ID'] = 'OOK-20260701-009'
        ..data['SignID'] = 'OOK-S009-a'
        ..data['写真ファイル名'] = 'OOK-20260701-009-a.jpg'
        ..data['全景写真ファイル名'] = 'OOK-20260701-009.jpg';
      final r = normalizeForExport([legacy('a'), other]);
      expect(r.rows[0]['CaptureID'], 'OOK-legacy-260701143512000');
      expect(r.rows[1]['CaptureID'], 'OOK-legacy-260701143512000-002');
      // zip 内のファイル名も衝突しない。
      final zipNames = r.photos.map((p) => p.zipName).toSet();
      expect(zipNames.length, r.photos.length);
    });

    test('旧・整図採集（全景欄が空）: 裁切図は photos に出し、元写真は空で sourceMissing', () {
      final full = Sign({
        'SignID': 'OOK-S010-a',
        '_status': 'pending',
        '写真ID': 'OOK-20260701-010',
        '写真ファイル名': 'OOK-20260701-010.jpg', // 旧仕様: 整図は全景を共用
        '全景写真ファイル名': '',
        '採集日時': '2026-07-01 15:00:00',
      });
      final r = normalizeForExport([full]);
      expect(r.rows.single['写真ファイル名'], 'OOK-legacy-260701150000000-a.jpg');
      expect(r.rows.single['元写真ファイル名'], '');
      expect(r.sourceMissing, [r.rows.single['SignID']]);
    });

    test('採集日時なし・SignID 不規則でも導出は失敗しない', () {
      final broken = Sign({'SignID': 'X', '_status': 'pending'});
      final r = normalizeForExport([broken]);
      expect(r.rows.single['CaptureID'], 'UNK-legacy-000000000000000');
      expect(r.rows.single['CropSuffix'], isNotEmpty);
      expect(r.rows.single['DisplayID'], 'X');
    });
  });

  group('normalizeForExport: 新レコードはそのまま', () {
    test('CaptureID を持つ行は書き換えない（DataStatus 補完のみ）', () {
      final s = Sign({
        'SignID': 'OOK-7Kx9Qp2A-260701143512482-a',
        '_status': 'human-reviewed',
        'CaptureID': 'OOK-7Kx9Qp2A-260701143512482',
        'DisplayID': 'OOK-20260701-008-a',
        '採集者ID': '7Kx9Qp2A',
        '写真ファイル名': 'OOK-7Kx9Qp2A-260701143512482-a.jpg',
        '元写真ファイル名': 'OOK-7Kx9Qp2A-260701143512482-source.jpg',
      });
      final r = normalizeForExport([s]);
      expect(r.rows.single['SignID'], s.id);
      expect(r.rows.single['CaptureID'], 'OOK-7Kx9Qp2A-260701143512482');
      expect(r.rows.single['DataStatus'], 'reviewed'); // human-reviewed の対応値
      // zip 名 = 本地名（複製・改名なし）。
      for (final p in r.photos) {
        expect(p.zipName, p.localName);
      }
    });

    test('新旧混在でも ID・zip名は全体で一意', () {
      final newer = Sign({
        'SignID': 'OOK-legacy-260701143512000-a', // 旧の採番結果と同名になる意地悪ケース
        'CaptureID': 'OOK-legacy-260701143512000',
        '写真ファイル名': 'OOK-legacy-260701143512000-a.jpg',
        '元写真ファイル名': 'OOK-legacy-260701143512000-source.jpg',
      });
      final old = Sign({
        'SignID': 'OOK-S008-a',
        '写真ID': 'OOK-20260701-008',
        '写真ファイル名': 'OOK-20260701-008-a.jpg',
        '全景写真ファイル名': 'OOK-20260701-008.jpg',
        '採集日時': '2026-07-01 14:35:12',
      });
      final r = normalizeForExport([newer, old]);
      final ids = r.rows.map((m) => m['SignID']).toSet();
      expect(ids.length, 2);
      expect(r.rows[1]['CaptureID'], 'OOK-legacy-260701143512000-002');
      final zipNames = r.photos.map((p) => p.zipName).toSet();
      expect(zipNames.length, r.photos.length);
    });
  });

  test('EntryMode/DataStatus: 新レコードの値は導出で書き換えない', () {
    final quick = Sign({
      'SignID': 'OOK-7Kx9Qp2A-260701143512482-a',
      '_status': 'pending',
      'CaptureID': 'OOK-7Kx9Qp2A-260701143512482',
      'EntryMode': 'quick',
      'DataStatus': 'raw',
    });
    final r = normalizeForExport([quick]);
    expect(r.rows.single['EntryMode'], 'quick');
    expect(r.rows.single['DataStatus'], 'raw'); // submitted 等に上書きしない
  });

  test('EntryMode/DataStatus: 旧レコードは DataStatus のみ _status から補完', () {
    final legacy = Sign({
      'SignID': 'OOK-S008-a',
      '_status': 'human-reviewed',
      '写真ID': 'OOK-20260701-008',
      '採集日時': '2026-07-01 14:35:12',
    });
    final r = normalizeForExport([legacy]);
    expect(r.rows.single['DataStatus'], 'reviewed');
    expect(r.rows.single['EntryMode'] ?? '', ''); // EntryMode は捏造しない
  });

  test('setStatus は _status と DataStatus を同時に揃える', () {
    final s = Sign({'SignID': 'X-a', '_status': 'pending'});
    s.setStatus('ai');
    expect(s.status, 'ai');
    expect(s.get('DataStatus'), 'ai_drafted');
    s.setStatus('final');
    expect(s.get('DataStatus'), 'verified');
  });
}
