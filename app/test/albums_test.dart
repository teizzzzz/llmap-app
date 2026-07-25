import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/albums.dart';

void main() {
  group('Album（相册モデル）', () {
    test('create: id は album_ 前綴＋時刻、名前は自由', () {
      final a = Album.create('新大久保', now: DateTime(2026, 7, 6, 12));
      expect(a.id, startsWith('album_'));
      expect(a.name, '新大久保');
      expect(a.recordIds, isEmpty);
      expect(a.createdAt, a.updatedAt);
    });

    test('addAll: 重複と空IDは追加しない。追加数を返し updatedAt を進める', () {
      final a = Album.create('A', now: DateTime(2026, 1, 1));
      final added = a.addAll(
        ['S1', 'S2', 'S1', ''],
        now: DateTime(2026, 1, 2),
      );
      expect(added, 2);
      expect(a.recordIds, ['S1', 'S2']);
      expect(a.updatedAt, isNot(a.createdAt));
      // 再追加は no-op
      expect(a.addAll(['S1']), 0);
    });

    test('removeAll: 相册から外すだけ（記録IDのリスト操作のみ）', () {
      final a = Album.create('A')..addAll(['S1', 'S2', 'S3']);
      expect(a.removeAll(['S2', 'S9']), 1);
      expect(a.recordIds, ['S1', 'S3']);
    });

    test('1記録は複数相册に所属できる', () {
      final a = Album.create('A')..addAll(['S1']);
      final b = Album.create('B')..addAll(['S1']);
      expect(a.contains('S1') && b.contains('S1'), isTrue);
    });

    test('JSON 往復（albums.json 形式）', () {
      final a = Album.create('新大久保', now: DateTime(2026, 7, 6))
        ..addAll(['SignID1', 'SignID2']);
      final restored = albumsFromJson(albumsToJson([a]));
      expect(restored.length, 1);
      expect(restored.first.id, a.id);
      expect(restored.first.name, '新大久保');
      expect(restored.first.recordIds, ['SignID1', 'SignID2']);
    });

    test('壊れた要素は読み飛ばして残りを返す', () {
      const broken = '{"version":1,"albums":['
          '{"id":"album_1","name":"ok","createdAt":"","updatedAt":"","recordIds":["S1"]},'
          '{"id":"","name":"no-id"},'
          '"not-an-object"'
          ']}';
      final out = albumsFromJson(broken);
      expect(out.length, 1);
      expect(out.first.name, 'ok');
    });

    test('相册削除＝リストから外すだけで記録側には何も無い（構造上の保証）', () {
      // Album は SignID の参照だけを持つ。toJson にも記録本体は含まれない。
      final a = Album.create('A')..addAll(['S1']);
      final j = a.toJson();
      expect(j.keys.toSet(),
          {'id', 'name', 'createdAt', 'updatedAt', 'recordIds'});
    });
  });
}
