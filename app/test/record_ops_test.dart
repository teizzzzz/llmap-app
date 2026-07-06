import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/record_ops.dart';

Sign sign(Map<String, dynamic> data) => Sign(Map<String, dynamic>.from(data));

void main() {
  group('orphanedPhotos（批量削除の写真安全計算）', () {
    test('共有元写真は残る記録が参照している限り削除対象にしない', () {
      // 1枚の元写真 pano.jpg から a/b の2つの sign を切り出したケース。
      final a = sign({
        'SignID': 'CAP1-a',
        '写真ファイル名': 'crop_a.jpg',
        '元写真ファイル名': 'pano.jpg',
      });
      final b = sign({
        'SignID': 'CAP1-b',
        '写真ファイル名': 'crop_b.jpg',
        '元写真ファイル名': 'pano.jpg',
      });
      final orphans = orphanedPhotos(deleting: [a], remaining: [b]);
      expect(orphans, {'crop_a.jpg'}); // crop は消せる
      expect(orphans.contains('pano.jpg'), isFalse); // 共有元写真は残す
    });

    test('最後の参照者を消すときは元写真も削除対象になる', () {
      final a = sign({
        'SignID': 'CAP1-a',
        '写真ファイル名': 'crop_a.jpg',
        '元写真ファイル名': 'pano.jpg',
      });
      final other = sign({
        'SignID': 'CAP2-a',
        '写真ファイル名': 'crop_x.jpg',
        '元写真ファイル名': 'pano2.jpg',
      });
      expect(
        orphanedPhotos(deleting: [a], remaining: [other]),
        {'crop_a.jpg', 'pano.jpg'},
      );
    });

    test('批量削除: 対象群の中で共有していても、全員消えるなら削除対象', () {
      final a = sign({'SignID': 'x-a', '写真ファイル名': 'a.jpg', '元写真ファイル名': 'p.jpg'});
      final b = sign({'SignID': 'x-b', '写真ファイル名': 'b.jpg', '元写真ファイル名': 'p.jpg'});
      expect(
        orphanedPhotos(deleting: [a, b], remaining: []),
        {'a.jpg', 'b.jpg', 'p.jpg'},
      );
    });

    test('旧字段（全景写真ファイル名）も参照として扱う', () {
      final legacy = sign({
        'SignID': 'old-a',
        '写真ファイル名': 'crop.jpg',
        '全景写真ファイル名': 'legacy_pano.jpg',
      });
      final keeper = sign({
        'SignID': 'old-b',
        '全景写真ファイル名': 'legacy_pano.jpg',
      });
      final orphans = orphanedPhotos(deleting: [legacy], remaining: [keeper]);
      expect(orphans, {'crop.jpg'});
    });

    test('空・「—」は写真参照に含めない', () {
      final s = sign({'SignID': 's', '写真ファイル名': '', '元写真ファイル名': '—'});
      expect(photoRefsOf(s), isEmpty);
    });
  });

  group('sortedSigns（表示排序）', () {
    final newer = sign({'SignID': 'n', 'DisplayID': 'B-2', '採集日時': '2026-07-02 10:00:00'});
    final older = sign({'SignID': 'o', 'DisplayID': 'A-1', '採集日時': '2026-07-01 09:00:00'});
    final noDate = sign({'SignID': 'x', 'DisplayID': 'C-3'});
    final badDate = sign({'SignID': 'y', 'DisplayID': 'D-4', '採集日時': 'not-a-date'});

    test('最新優先 / 最旧優先', () {
      expect(sortedSigns([older, newer], GallerySort.newestFirst).first.id, 'n');
      expect(sortedSigns([newer, older], GallerySort.oldestFirst).first.id, 'o');
    });

    test('採集日時なし・解析不能の旧データは末尾（崩れない）', () {
      for (final sort in [GallerySort.newestFirst, GallerySort.oldestFirst]) {
        final out = sortedSigns([noDate, newer, badDate, older], sort);
        expect(out.length, 4);
        expect(out.sublist(2).map((s) => s.id).toSet(), {'x', 'y'});
      }
    });

    test('DisplayID 昇順 / 降順', () {
      final out = sortedSigns([newer, older, noDate], GallerySort.displayIdAsc);
      expect(out.map((s) => s.displayId).toList(), ['A-1', 'B-2', 'C-3']);
      final desc = sortedSigns([older, noDate, newer], GallerySort.displayIdDesc);
      expect(desc.first.displayId, 'C-3');
    });

    test('元リストを変更しない（表示のみ）', () {
      final list = [newer, older];
      sortedSigns(list, GallerySort.oldestFirst);
      expect(list.first.id, 'n');
    });
  });

  group('GalleryFilter（表示筛选）', () {
    final s = sign({
      'SignID': 'CAP-a',
      '主要言語': '日本語/韓国語',
      '設置主体': 'top-down(標準化)',
      'EntryMode': 'quick',
      'DataStatus': 'raw',
      '地区コード': 'OOK',
      '採集者ID': 'AB12',
      '緯度': 35.6,
      '経度': 139.7,
      '写真ファイル名': 'c.jpg',
      '元写真ファイル名': '',
    });

    test('言語は併記を展開して照合する', () {
      final f = GalleryFilter()..language = '韓国語';
      expect(f.matches(s), isTrue);
      f.language = '中国語';
      expect(f.matches(s), isFalse);
    });

    test('EntryMode / DataStatus / 地区 / 採集者', () {
      final f = GalleryFilter()
        ..entryMode = 'quick'
        ..dataStatus = 'raw'
        ..areaCode = 'OOK'
        ..collectorId = 'AB12';
      expect(f.matches(s), isTrue);
      f.entryMode = 'research';
      expect(f.matches(s), isFalse);
    });

    test('DataStatus 未併記の旧データは _status から導出して照合', () {
      final legacy = sign({'SignID': 'L', '_status': 'final'});
      final f = GalleryFilter()..dataStatus = 'verified';
      expect(f.matches(legacy), isTrue);
    });

    test('GPS / 写真 / 元写真の有無', () {
      final f = GalleryFilter()
        ..hasGps = true
        ..hasPhoto = true
        ..hasSource = false;
      expect(f.matches(s), isTrue);
      f.hasSource = true;
      expect(f.matches(s), isFalse);
    });

    test('activeCount と clear', () {
      final f = GalleryFilter()
        ..language = '日本語'
        ..hasGps = true;
      expect(f.activeCount, 2);
      expect(f.isActive, isTrue);
      f.clear();
      expect(f.isActive, isFalse);
      expect(f.matches(s), isTrue); // 空筛选はすべて通す
    });
  });
}
