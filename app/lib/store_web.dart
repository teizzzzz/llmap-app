/// Web 試用版の永続化層。端末版（store_io.dart）と同じ API を、ブラウザ内で実装する。
/// - 記録・相册: IndexedDB `llmap_trial` の `kv`（JSON 文字列）
/// - 写真: 同 `photos`（名前 → バイト列）。起動時にメモリへ読み込み、同期で参照できる
/// 訪問者ごとのブラウザにだけ保存され、サーバ（NAS）へは何も送らない。
/// 書き出しは zip をメモリで作り、ブラウザのダウンロードとして渡す。
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

import 'albums.dart';
import 'dataset_package.dart';
import 'export_normalizer.dart';
import 'imaging.dart';
import 'models.dart';
import 'store_common.dart';

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  /// Web 試用版（設定に「試用をリセット」を出す等の分岐に使う）。
  static const bool isWebTrial = true;

  static const _dbName = 'llmap_trial';
  static const _photos = 'photos';
  static const _kv = 'kv';

  Database? _db;
  final Map<String, Uint8List> _mem = {};
  Future<void>? _opening;

  Future<void> _ensure() => _opening ??= _open();

  Future<void> _open() async {
    try {
      final db = await getIdbFactory()!.open(_dbName, version: 1,
          onUpgradeNeeded: (e) {
        final d = e.database;
        if (!d.objectStoreNames.contains(_photos)) d.createObjectStore(_photos);
        if (!d.objectStoreNames.contains(_kv)) d.createObjectStore(_kv);
      });
      final txn = db.transaction(_photos, idbModeReadOnly);
      await txn.objectStore(_photos).openCursor(autoAdvance: true).forEach((c) {
        final v = c.value;
        if (v is Uint8List) {
          _mem['${c.key}'] = v;
        } else if (v is List) {
          _mem['${c.key}'] = Uint8List.fromList(v.cast<int>());
        }
      });
      await txn.completed;
      _db = db;
    } catch (_) {
      // プライベートブラウズ等で IndexedDB が使えない: このタブの間だけメモリで動かす。
      _db = null;
    }
  }

  Future<String?> _get(String key) async {
    final db = _db;
    if (db == null) return _memKv[key];
    final txn = db.transaction(_kv, idbModeReadOnly);
    final v = await txn.objectStore(_kv).getObject(key);
    await txn.completed;
    return v as String?;
  }

  final Map<String, String> _memKv = {};

  Future<void> _put(String key, String value) async {
    _memKv[key] = value;
    final db = _db;
    if (db == null) return;
    final txn = db.transaction(_kv, idbModeReadWrite);
    await txn.objectStore(_kv).put(value, key);
    await txn.completed;
  }

  bool hasPhotoSync(String name) => name.isNotEmpty && _mem.containsKey(name);

  ImageProvider photoImage(String name) =>
      MemoryImage(_mem[name] ?? _blank);

  // 1×1 の透明 PNG（写真が無いときの代わり。呼び出し側の errorBuilder に頼らない）。
  static final Uint8List _blank = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

  Future<Uint8List?> readPhoto(String name) async {
    await _ensure();
    return _mem[name];
  }

  Future<bool> hasPhoto(String name) async {
    if (name.isEmpty) return false;
    await _ensure();
    return _mem.containsKey(name);
  }

  Future<int> deletePhotos(Set<String> names) async {
    await _ensure();
    var deleted = 0;
    final db = _db;
    final txn = db?.transaction(_photos, idbModeReadWrite);
    for (final name in names) {
      if (name.isEmpty) continue;
      if (_mem.remove(name) != null) deleted++;
      await txn?.objectStore(_photos).delete(name);
    }
    await txn?.completed;
    return deleted;
  }

  /// 端末版と同じ規則: 同名・同内容はそのまま、同名・別内容は `名前~2.jpg` で保存。
  Future<String> savePhoto(String name, Uint8List bytes) async {
    await _ensure();
    var target = name;
    var n = 2;
    while (_mem.containsKey(target)) {
      if (_sameBytes(_mem[target]!, bytes)) return target;
      final dot = name.lastIndexOf('.');
      final stem = dot < 0 ? name : name.substring(0, dot);
      final ext = dot < 0 ? '' : name.substring(dot);
      target = '$stem~$n$ext';
      n++;
    }
    _mem[target] = bytes;
    final db = _db;
    if (db != null) {
      try {
        final txn = db.transaction(_photos, idbModeReadWrite);
        await txn.objectStore(_photos).put(bytes, target);
        await txn.completed;
      } catch (_) {
        // 容量超過など: このタブの間はメモリに残る（再読み込みで消える）。
      }
    }
    return target;
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<Album>> loadAlbums() async {
    await _ensure();
    try {
      final s = await _get('albums');
      return s == null ? [] : albumsFromJson(s);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlbums(List<Album> albums) async {
    await _ensure();
    await _put('albums', albumsToJson(albums));
  }

  Future<void> saveProject(List<Sign> signs, String area, int nextSeq) async {
    await _ensure();
    await _put(
        'project',
        jsonEncode({
          'version': 1,
          'area': area,
          'nextSeq': nextSeq,
          'signs': signs.map((s) => s.toJson()).toList(),
        }));
  }

  Future<ProjectState?> loadProject() async {
    await _ensure();
    try {
      final s = await _get('project');
      if (s == null) return null;
      final map = jsonDecode(s) as Map<String, dynamic>;
      return ProjectState(
        signs: (map['signs'] as List? ?? [])
            .map((e) => Sign.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        area: (map['area'] ?? 'OOK').toString(),
        nextSeq: (map['nextSeq'] is int)
            ? map['nextSeq'] as int
            : int.tryParse('${map['nextSeq']}') ?? 1,
      );
    } catch (_) {
      return null;
    }
  }

  /// Dataset Package を作り、ブラウザのダウンロードとして渡す。ファイル名を返す。
  /// 中身の構造は端末版と同じ（dataset_package.dart / export_normalizer.dart）。
  Future<String> buildBundle(
    List<Sign> signs,
    AppSchema schema, {
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensure();
    final norm = normalizeForExport(signs);
    final stats = <PhotoStat>[
      for (final p in norm.photos)
        _mem.containsKey(p.localName)
            ? PhotoStat(p, exists: true, sizeBytes: _mem[p.localName]!.length)
            : PhotoStat(p, exists: false),
    ];
    final included = stats.where((s) => s.exists).toList();
    onProgress?.call(0, included.length);

    final exportedAt = DateTime.now();
    final name = datasetFileName(exportedAt);
    const json = JsonEncoder.withIndent('  ');
    Uint8List enc(String s) => Uint8List.fromList(utf8.encode(s));
    final archive = Archive();
    void add(String path, Uint8List bytes) =>
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
    add('data.csv', enc(signsToCsv(norm.rows, header: schema.csvHeader)));
    add(
        'metadata.json',
        enc(json.convert(buildMetadataJson(
          recordCount: signs.length,
          stats: stats,
          norm: norm,
          exportedAt: exportedAt,
        ))));
    add('schema.json', enc(json.convert(buildSchemaJson(schema))));
    add('manifest.json', enc(json.convert(buildManifestJson(stats, norm))));
    add('MANIFEST.txt', enc(buildManifestTxt(signs.length, stats, norm)));
    add('README.md', enc(buildReadme()));
    var done = 0;
    for (final s in included) {
      add(zipPathFor(s.photo), _mem[s.photo.localName]!);
      onProgress?.call(++done, included.length);
      // 進捗の描画に間を空ける（圧縮は同じスレッドで走るため）。
      if (done % 8 == 0) await Future<void>.delayed(Duration.zero);
    }
    final zip = Uint8List.fromList(ZipEncoder().encode(archive)!);
    _download(name, zip, 'application/zip');
    return name;
  }

  void _download(String name, Uint8List bytes, String type) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body!.appendChild(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
  }

  /// Web 試用版ではダウンロード済み。名前をそのまま返す。
  Future<String> copyToDownloads(String zipPath) async => zipPath;

  /// 試用をリセット: この訪問者が撮った写真・記録・相册をすべて消す。
  Future<void> resetTrial() async {
    await _ensure();
    _mem.clear();
    _memKv.clear();
    final db = _db;
    if (db == null) return;
    final txn = db.transaction([_photos, _kv], idbModeReadWrite);
    await txn.objectStore(_photos).clear();
    await txn.objectStore(_kv).clear();
    await txn.completed;
  }
}
