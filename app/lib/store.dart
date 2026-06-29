/// ローカル永続化層（C 計画）。採集記録と写真を端末内に保存し、再起動後も復元する。
/// - `<docs>/llmap/project.json` : 採集記録（疎なMapの配列）＋地区/連番
/// - `<docs>/llmap/photos/<name>` : 全景・裁切の JPEG
/// 後端を介さず端末だけで採集→保存→書き出しを完結させる。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

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

  File photoFile(String name) => File('${_photos!.path}/$name');

  Future<bool> hasPhoto(String name) async {
    if (name.isEmpty) return false;
    await _ensure();
    return photoFile(name).exists();
  }

  /// 写真（全景/裁切）を端末に保存。同名は上書き。
  Future<void> savePhoto(String name, Uint8List bytes) async {
    await _ensure();
    await photoFile(name).writeAsBytes(bytes, flush: true);
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
        area: (map['area'] ?? 'HAS').toString(),
        nextSeq: (map['nextSeq'] is int)
            ? map['nextSeq'] as int
            : int.tryParse('${map['nextSeq']}') ?? 1,
      );
    } catch (_) {
      return null; // 壊れた保存は無視して新規扱い
    }
  }

  /// CSV＋参照写真を 1つの ZIP にまとめて一時ファイルへ書き出し、パスを返す。
  /// backend /export_bundle のローカル版（PC off でも書き出せる）。
  /// [onProgress] は写真を1枚追加するごとに (done, total) を通知する。
  /// 大量画像でもメモリを抱えないよう ZipFileEncoder でストリーミング書き込みする。
  Future<String> buildBundle(
    List<Sign> signs,
    List<String> csvHeader, {
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensure();

    // 参照写真を集計（存在するものだけ同梱）。
    final wanted = <String>{};
    for (final s in signs) {
      for (final k in ['写真ファイル名', '全景写真ファイル名']) {
        final name = s.get(k);
        if (name.isNotEmpty) wanted.add(name);
      }
    }
    final existing = <String>[];
    final missing = <String>[];
    for (final name in wanted.toList()..sort()) {
      if (await photoFile(name).exists()) {
        existing.add(name);
      } else {
        missing.add(name);
      }
    }
    final total = existing.length;
    onProgress?.call(0, total);

    final out = File('${Directory.systemTemp.path}/llmap_export.zip');
    if (await out.exists()) await out.delete();

    final encoder = ZipFileEncoder();
    encoder.create(out.path);
    try {
      // data.csv（メモリ内データ）
      final csvBytes = utf8.encode(
          signsToCsv(signs.map((s) => s.toJson()).toList(), header: csvHeader));
      encoder.addArchiveFile(ArchiveFile('data.csv', csvBytes.length, csvBytes));

      // 写真をファイルから直接ストリーミング追加（1枚ごとに進捗通知）。
      var done = 0;
      for (final name in existing) {
        await encoder.addFile(photoFile(name), 'photos/$name');
        done++;
        onProgress?.call(done, total);
      }

      final manifest = StringBuffer()
        ..writeln('records: ${signs.length}')
        ..writeln('photos_included: ${existing.length}')
        ..writeln('photos_missing: ${missing.length}');
      for (final m in missing) {
        manifest.writeln('  - $m');
      }
      final mb = utf8.encode(manifest.toString());
      encoder.addArchiveFile(ArchiveFile('MANIFEST.txt', mb.length, mb));
    } finally {
      await encoder.close();
    }
    return out.path;
  }
}
