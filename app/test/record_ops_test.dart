import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/albums.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/record_ops.dart';

Sign sign(Map<String, dynamic> data) => Sign(Map<String, dynamic>.from(data));

void main() {
  group('exportCandidates（導出範囲 / Step 14）', () {
    final a = sign({'SignID': 'S-a', '主要言語': '日本語'});
    final b = sign({'SignID': 'S-b', '主要言語': '韓国語'});
    final c = sign({'SignID': 'S-c', '主要言語': '中国語'});
    final all = [a, b, c];

    test('all: 全記録（旧行動）を新しいリストで返す', () {
      final out = exportCandidates(scope: ExportScope.all, allSigns: all);
      expect(out.map((s) => s.id).toList(), ['S-a', 'S-b', 'S-c']);
      out.removeAt(0);
      expect(all.length, 3); // 元リストは不変
    });

    test('currentView: 渡された表示リストをそのまま使う（過濾は再実装しない）', () {
      final out = exportCandidates(
          scope: ExportScope.currentView, allSigns: all, visible: [c, a]);
      expect(out.map((s) => s.id).toList(), ['S-c', 'S-a']); // 表示順を保持
    });

    test('selected: 選択集合に一致する記録。空選択は空。順序は allSigns 順', () {
      expect(
        exportCandidates(
            scope: ExportScope.selected, allSigns: all, selected: {c, a})
            .map((s) => s.id)
            .toList(),
        ['S-a', 'S-c'],
      );
      expect(
        exportCandidates(scope: ExportScope.selected, allSigns: all),
        isEmpty,
      );
    });

    test('currentAlbum: recordIds 対応のみ。削除済み ID は無視。相册なしは空', () {
      final album = Album.create('A')..addAll(['S-b', 'S-deleted', 'S-c']);
      final out = exportCandidates(
          scope: ExportScope.currentAlbum, allSigns: all, currentAlbum: album);
      expect(out.map((s) => s.id).toList(), ['S-b', 'S-c']);
      expect(
        exportCandidates(scope: ExportScope.currentAlbum, allSigns: all),
        isEmpty,
      );
    });

    test('album: 選んだ相册の記録のみ（規則は currentAlbum と同一）', () {
      final album = Album.create('選択用')..addAll(['S-a', 'S-gone']);
      final out = exportCandidates(
          scope: ExportScope.album, allSigns: all, currentAlbum: album);
      expect(out.map((s) => s.id).toList(), ['S-a']); // 削除済み ID は無視
      expect(
        exportCandidates(scope: ExportScope.album, allSigns: all),
        isEmpty, // 相册未指定は空
      );
    });

    test('unfiled / filed: 归納状態と同じ規則', () {
      final albums = [Album.create('A')..addAll(['S-b'])];
      expect(
        exportCandidates(
                scope: ExportScope.unfiled, allSigns: all, albums: albums)
            .map((s) => s.id)
            .toList(),
        ['S-a', 'S-c'],
      );
      expect(
        exportCandidates(
                scope: ExportScope.filed, allSigns: all, albums: albums)
            .map((s) => s.id)
            .toList(),
        ['S-b'],
      );
    });

    test('どの範囲も記録データ本体を変更しない', () {
      final before = a.data.toString();
      for (final scope in ExportScope.values) {
        exportCandidates(
          scope: scope,
          allSigns: all,
          visible: [a],
          selected: {a},
          currentAlbum: Album.create('X')..addAll(['S-a']),
          albums: [Album.create('Y')..addAll(['S-b'])],
        );
      }
      expect(a.data.toString(), before);
    });
  });

  group('AlbumStatusFilter（相册归納状態 / Step 12.1）', () {
    final unfiledSign = sign({'SignID': 'S-unfiled', '主要言語': '日本語',
        'EntryMode': 'quick', '採集日時': '2026-07-01 10:00:00'});
    final filedSign = sign({'SignID': 'S-filed', '主要言語': '韓国語',
        'EntryMode': 'research', '採集日時': '2026-07-02 10:00:00'});
    final doubleFiled = sign({'SignID': 'S-double', '主要言語': '日本語',
        '採集日時': '2026-07-03 10:00:00'});
    List<Album> albums() => [
          Album.create('A')..addAll(['S-filed', 'S-double']),
          Album.create('B')..addAll(['S-double']),
        ];
    final signs = [unfiledSign, filedSign, doubleFiled];

    test('isFiled: いずれかの相册に所属していれば true', () {
      final a = albums();
      expect(isFiled(unfiledSign, a), isFalse);
      expect(isFiled(filedSign, a), isTrue);
      expect(isFiled(doubleFiled, a), isTrue);
      expect(isFiled(filedSign, const []), isFalse); // 相册ゼロなら全員未分類
    });

    test('unfiled: どの相册にも属さない記録のみ', () {
      final out = applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.unfiled);
      expect(out.map((s) => s.id).toList(), ['S-unfiled']);
    });

    test('all: すべての記録（分類済みも含む）', () {
      final out = applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.all);
      expect(out.length, 3);
    });

    test('filed: 少なくとも1つの相册に属する記録。複数相册所属でも1回だけ', () {
      final out = applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.filed);
      expect(out.map((s) => s.id).toList(), ['S-filed', 'S-double']);
      expect(out.where((s) => s.id == 'S-double').length, 1);
    });

    test('相册から全部外す/相册削除 → unfiled に戻る', () {
      final a = albums();
      // 全相册から外す
      for (final album in a) {
        album.removeAll(['S-double']);
      }
      var out = applyAlbumStatusFilter(signs, a, AlbumStatusFilter.unfiled);
      expect(out.map((s) => s.id).toSet(), {'S-unfiled', 'S-double'});
      // 相册削除（リストから除去）→ 他の相册に属さない記録は unfiled へ
      final b = albums()..removeWhere((al) => al.name == 'A');
      out = applyAlbumStatusFilter(signs, b, AlbumStatusFilter.unfiled);
      expect(out.map((s) => s.id).toSet(), {'S-unfiled', 'S-filed'});
      // S-double は相册 B にまだ属するので filed のまま
      expect(isFiled(doubleFiled, b), isTrue);
    });

    test('归納状態は既存筛选と叠加できる（表示のみ・記録は不変）', () {
      final f = GalleryFilter()..language = '日本語';
      final unfiledJa = applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.unfiled)
          .where(f.matches)
          .toList();
      expect(unfiledJa.map((s) => s.id).toList(), ['S-unfiled']);
      final filedJa = applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.filed)
          .where(f.matches)
          .toList();
      expect(filedJa.map((s) => s.id).toList(), ['S-double']);
      expect(signs.length, 3); // 元データは不変
    });

    test('归納状態のあとに排序も従来どおり効く', () {
      final out = sortedSigns(
        applyAlbumStatusFilter(signs, albums(), AlbumStatusFilter.filed),
        GallerySort.newestFirst,
      );
      expect(out.map((s) => s.id).toList(), ['S-double', 'S-filed']);
    });
  });

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
