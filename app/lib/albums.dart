/// 相册（アルバム）: 端末内だけの整理機能（Step 12 Phase 2）。
/// 記録の SignID を相册にひも付けるだけで、記録本体・SignID・写真ファイル・
/// CSV / Dataset Package 導出には**一切影響しない**（albums.json は導出対象外）。
/// 保存先は `<docs>/llmap/albums.json`（LocalStore.loadAlbums/saveAlbums）。
library;

import 'dart:convert';

class Album {
  final String id; // album_<microsecondsSinceEpoch>。改名しても不変。
  String name;
  final String createdAt; // ISO8601
  String updatedAt; // ISO8601
  final List<String> recordIds; // SignID。1記録は複数相册に所属できる。

  Album({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    List<String>? recordIds,
  }) : recordIds = recordIds ?? [];

  factory Album.create(String name, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    final iso = ts.toIso8601String();
    return Album(
      id: 'album_${ts.microsecondsSinceEpoch}',
      name: name,
      createdAt: iso,
      updatedAt: iso,
    );
  }

  bool contains(String signId) => recordIds.contains(signId);

  /// 記録を追加（既所属は重複させない）。実際に追加した数を返す。
  int addAll(Iterable<String> signIds, {DateTime? now}) {
    var added = 0;
    for (final id in signIds) {
      if (id.isEmpty || recordIds.contains(id)) continue;
      recordIds.add(id);
      added++;
    }
    if (added > 0) _touch(now);
    return added;
  }

  /// 記録を相册から外す（記録本体は削除しない）。外した数を返す。
  int removeAll(Iterable<String> signIds, {DateTime? now}) {
    final target = signIds.toSet();
    final before = recordIds.length;
    recordIds.removeWhere(target.contains);
    final removed = before - recordIds.length;
    if (removed > 0) _touch(now);
    return removed;
  }

  void rename(String newName, {DateTime? now}) {
    name = newName;
    _touch(now);
  }

  void _touch(DateTime? now) {
    updatedAt = (now ?? DateTime.now()).toIso8601String();
  }

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        createdAt: (j['createdAt'] ?? '').toString(),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        recordIds: List<String>.from(j['recordIds'] ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'recordIds': recordIds,
      };
}

/// albums.json の文字列 → 相册一覧。壊れた要素は読み飛ばす（起動を止めない）。
List<Album> albumsFromJson(String source) {
  final map = jsonDecode(source) as Map<String, dynamic>;
  final out = <Album>[];
  for (final e in (map['albums'] as List? ?? const [])) {
    try {
      final a = Album.fromJson(Map<String, dynamic>.from(e));
      if (a.id.isNotEmpty) out.add(a);
    } catch (_) {
      // 壊れた1件のために全体を失わない
    }
  }
  return out;
}

/// 相册一覧 → albums.json の文字列。
String albumsToJson(List<Album> albums) => jsonEncode({
      'version': 1,
      'albums': albums.map((a) => a.toJson()).toList(),
    });
