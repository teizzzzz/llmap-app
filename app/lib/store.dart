/// ローカル永続化層（C 計画）。採集記録と写真を端末内に保存し、再起動後も復元する。
/// - `<docs>/llmap/project.json` : 採集記録（疎なMapの配列）＋地区/連番
/// - `<docs>/llmap/photos/<name>` : 全景・裁切の JPEG
/// 後端を介さず端末だけで採集→保存→書き出しを完結させる。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import 'albums.dart';
import 'dataset_package.dart';
import 'export_normalizer.dart';
import 'imaging.dart';
import 'models.dart';

class ProjectState {
  final List<Sign> signs;
  final String area;
  final int nextSeq;
  ProjectState({required this.signs, required this.area, required this.nextSeq});
}

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  Directory? _root;
  Directory? _photos;

  Future<void> _ensure() async {
    if (_root != null) return;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/llmap');
    _photos = Directory('${_root!.path}/photos');
    await _photos!.create(recursive: true);
  }

  File _projectFile() => File('${_root!.path}/project.json');

  File _albumsFile() => File('${_root!.path}/albums.json');

  File photoFile(String name) => File('${_photos!.path}/$name');

  /// 写真ファイルを削除する（存在しないものは無視）。削除できた数を返す。
  /// **必ず record_ops.orphanedPhotos で「残る記録から参照されない」名前だけを
  /// 渡すこと** — 共有元写真（1图多sign）を誤って消さないため。
  Future<int> deletePhotos(Set<String> names) async {
    await _ensure();
    var deleted = 0;
    for (final name in names) {
      if (name.isEmpty) continue;
      final f = photoFile(name);
      if (await f.exists()) {
        await f.delete();
        deleted++;
      }
    }
    return deleted;
  }

  /// 相册一覧を読む（無ければ空。壊れた保存は無視して空扱い）。
  Future<List<Album>> loadAlbums() async {
    await _ensure();
    final f = _albumsFile();
    if (!await f.exists()) return [];
    try {
      return albumsFromJson(await f.readAsString());
    } catch (_) {
      return [];
    }
  }

  /// 相册一覧を保存する。相册は端末内の整理機能で、Dataset Package には入らない。
  Future<void> saveAlbums(List<Album> albums) async {
    await _ensure();
    await _albumsFile().writeAsString(albumsToJson(albums), flush: true);
  }

  Future<bool> hasPhoto(String name) async {
    if (name.isEmpty) return false;
    await _ensure();
    return photoFile(name).exists();
  }

  /// 写真（元写真/裁切）を端末に保存し、**実際に保存したファイル名**を返す。
  /// - 同名で内容が同一: 書き込みをスキップしてそのまま返す。
  /// - 同名で内容が異なる: 静黙上書きせず `名前~2.jpg` 形式の衝突回避名で保存する
  ///   （多人採集データの取り込み・合并時にデータを失わないための保護）。
  Future<String> savePhoto(String name, Uint8List bytes) async {
    await _ensure();
    var target = name;
    var n = 2;
    while (await photoFile(target).exists()) {
      final existing = await photoFile(target).readAsBytes();
      if (_sameBytes(existing, bytes)) return target; // 同一内容 → スキップ
      final dot = name.lastIndexOf('.');
      final stem = dot < 0 ? name : name.substring(0, dot);
      final ext = dot < 0 ? '' : name.substring(dot);
      target = '$stem~$n$ext';
      n++;
    }
    await photoFile(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 採集記録＋セッション（地区/連番）を JSON で保存。変更ごとに呼ぶ。
  Future<void> saveProject(List<Sign> signs, String area, int nextSeq) async {
    await _ensure();
    final json = jsonEncode({
      'version': 1,
      'area': area,
      'nextSeq': nextSeq,
      'signs': signs.map((s) => s.toJson()).toList(),
    });
    await _projectFile().writeAsString(json, flush: true);
  }

  /// 保存済みの採集記録を復元。無ければ null。
  Future<ProjectState?> loadProject() async {
    await _ensure();
    final f = _projectFile();
    if (!await f.exists()) return null;
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final signs = (map['signs'] as List? ?? [])
          .map((s) => Sign.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      return ProjectState(
        signs: signs,
        area: (map['area'] ?? 'OOK').toString(),
        nextSeq: (map['nextSeq'] is int)
            ? map['nextSeq'] as int
            : int.tryParse('${map['nextSeq']}') ?? 1,
      );
    } catch (_) {
      return null; // 壊れた保存は無視して新規扱い
    }
  }

  /// Dataset Package（llmap_dataset_YYYYMMDD_HHMMSS.zip）を一時ファイルへ
  /// 書き出し、パスを返す。構造は dataset_package.dart / docs/data-contract.md §5。
  /// 導出前に規範化（export_normalizer）を通し、旧レコードも新データ契約で出す
  /// （本地の記録・写真ファイルは書き換えない。導出包内でのみ新名に複製）。
  /// [onProgress] は写真を1枚追加するごとに (done, total) を通知する。
  /// 圧縮は**別アイソレート**で実行し、UI スレッドを固めない（進捗はポートで受信）。
  Future<String> buildBundle(
    List<Sign> signs,
    AppSchema schema, {
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensure();

    final norm = normalizeForExport(signs);

    // 参照写真の存在確認（本地に存在するものだけ同梱）。CSV と zip 内の名前は必ず一致。
    final stats = <PhotoStat>[];
    for (final p in norm.photos) {
      final f = photoFile(p.localName);
      stats.add(await f.exists()
          ? PhotoStat(p, exists: true, sizeBytes: await f.length())
          : PhotoStat(p, exists: false));
    }
    final included = stats.where((s) => s.exists).toList();
    final total = included.length;
    onProgress?.call(0, total);

    final exportedAt = DateTime.now();
    final out =
        File('${Directory.systemTemp.path}/${datasetFileName(exportedAt)}');
    if (await out.exists()) await out.delete();

    const json = JsonEncoder.withIndent('  ');
    Uint8List enc(String s) => Uint8List.fromList(utf8.encode(s));
    // zip 冒頭に置くテキスト類（[zip内パス, 内容]）。manifest.json が主フォーマット。
    final textEntries = <List<Object>>[
      ['data.csv', enc(signsToCsv(norm.rows, header: schema.csvHeader))],
      [
        'metadata.json',
        enc(json.convert(buildMetadataJson(
          recordCount: signs.length,
          stats: stats,
          norm: norm,
          exportedAt: exportedAt,
        ))),
      ],
      ['schema.json', enc(json.convert(buildSchemaJson(schema)))],
      ['manifest.json', enc(json.convert(buildManifestJson(stats, norm)))],
      ['MANIFEST.txt', enc(buildManifestTxt(signs.length, stats, norm))],
      ['README.md', enc(buildReadme())],
    ];
    // [zip内パス, 実ファイルパス]。crop → photos/、source → source_photos/。
    final photos = [
      for (final s in included)
        [zipPathFor(s.photo), photoFile(s.photo.localName).path],
    ];

    // 別アイソレートで圧縮。進捗・完了・エラーをポートで受け取る。
    final rp = ReceivePort();
    final completer = Completer<void>();
    final isolate = await Isolate.spawn(
      _zipWorker,
      _ZipJob(rp.sendPort, out.path, textEntries, photos),
    );
    rp.listen((msg) {
      if (msg is List<int>) {
        onProgress?.call(msg[0], msg[1]);
      } else if (msg == 'ok') {
        rp.close();
        if (!completer.isCompleted) completer.complete();
      } else if (msg is String && msg.startsWith('err:')) {
        rp.close();
        if (!completer.isCompleted) {
          completer.completeError(Exception(msg.substring(4)));
        }
      }
    });
    try {
      await completer.future;
    } finally {
      isolate.kill(priority: Isolate.immediate);
    }
    return out.path;
  }
}

/// 別アイソレートに渡すジョブ（全フィールド sendable）。
class _ZipJob {
  final SendPort port;
  final String outPath;
  final List<List<Object>> textEntries; // [zip内パス, Uint8List]
  final List<List<String>> photos; // [zip内パス, 実ファイルパス]
  _ZipJob(this.port, this.outPath, this.textEntries, this.photos);
}

/// 別アイソレートで ZIP をストリーミング生成（重い deflate をここで実行）。
Future<void> _zipWorker(_ZipJob job) async {
  try {
    final encoder = ZipFileEncoder();
    encoder.create(job.outPath);
    for (final e in job.textEntries) {
      final bytes = e[1] as Uint8List;
      encoder.addArchiveFile(ArchiveFile(e[0] as String, bytes.length, bytes));
    }
    final total = job.photos.length;
    var done = 0;
    for (final p in job.photos) {
      await encoder.addFile(File(p[1]), p[0]);
      done++;
      job.port.send(<int>[done, total]); // 進捗通知
    }
    await encoder.close();
    job.port.send('ok');
  } catch (e) {
    job.port.send('err:$e');
  }
}
