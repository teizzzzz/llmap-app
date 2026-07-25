/// 導出時規範化（export-time normalization）。
///
/// 旧レコードは本地では**一切書き換えず**、CSV/ZIP 導出の瞬間だけ
/// 新データ契約（CaptureID 中心・docs/data-contract.md）へ変換する。
/// - 本地の project.json・旧写真ファイル名はそのまま。
/// - 導出包内の写真は新規則名にリネームして複製し、CSV と必ず一致させる。
/// - 旧データに CollectorID は捏造しない（`legacy` 固定。端末の現IDを入れると
///   データ来源を誤らせるため）。
///
/// 純ロジック（File I/O なし）。写真の存在確認・複製は store.buildBundle が行う。
library;

import 'models.dart';

/// 導出包に入れる写真1枚（zip内の新名 → 本地の実ファイル名）。
class ExportPhoto {
  final String zipName; // 導出包内・CSV に書く名前
  final String localName; // 端末内の実ファイル名（旧名のまま）
  final String type; // 'crop'（裁切図） | 'source'（元写真）
  final String captureId; // 所属する撮影イベント
  final String signId; // crop のみ。source は複数 sign が共有するため ''
  const ExportPhoto(
    this.zipName,
    this.localName, {
    required this.type,
    required this.captureId,
    this.signId = '',
  });
}

/// 規範化の結果。rows は入力 signs と同順。
class NormalizedExport {
  final List<Map<String, dynamic>> rows;
  final List<ExportPhoto> photos; // zipName で一意
  final List<String> sourceMissing; // 元写真が特定できない SignID（導出後の値）

  /// 導出時に規範化された旧レコードの対応表
  /// （{signId: 新SignID, legacySignId: 旧SignID, captureId}）。manifest.json 用。
  final List<Map<String, String>> normalizedLegacy;

  const NormalizedExport(
      this.rows, this.photos, this.sourceMissing, this.normalizedLegacy);
}

/// signs を導出用に規範化する。
/// - CaptureID を持つ新レコード: そのまま（DataStatus のみ欠けていれば補完）。
/// - 旧レコード: CaptureID `AREA-legacy-YYMMDDHHMMSS000` を生成し、
///   SignID/写真名/新字段を新規則へ写像する。同一 写真ID の裁切群は同じ
///   CaptureID を共有し、元写真の追跡関係を保つ。
NormalizedExport normalizeForExport(List<Sign> signs) {
  final rows = <Map<String, dynamic>>[];
  final photoByZip = <String, ExportPhoto>{}; // zipName で一意
  final sourceMissing = <String>[];
  final normalizedLegacy = <Map<String, String>>[];
  final usedCaptureIds = <String>{};
  final usedSignIds = <String>{};
  // 旧レコードは撮影イベント（写真ID）単位で同じ CaptureID を共有する。
  final groupCaptureId = <String, String>{};

  // 先に新レコードの ID を予約し、旧レコードの採番が新と衝突しないようにする。
  for (final s in signs) {
    if (s.get('CaptureID').isNotEmpty) {
      usedCaptureIds.add(s.get('CaptureID'));
      usedSignIds.add(s.id);
    }
  }

  for (var i = 0; i < signs.length; i++) {
    final s = signs[i];
    final map = Map<String, dynamic>.from(s.data);

    if (s.get('CaptureID').isNotEmpty) {
      // 新契約レコード: 実ファイル名がそのまま導出名。
      if (s.get('DataStatus').isEmpty) {
        map['DataStatus'] = dataStatusFor(s.status);
      }
      if (s.fileName.isNotEmpty) {
        photoByZip[s.fileName] = ExportPhoto(s.fileName, s.fileName,
            type: 'crop', captureId: s.captureId, signId: s.id);
      }
      final src = s.sourceFileName;
      if (src.isNotEmpty) {
        photoByZip.putIfAbsent(
            src,
            () => ExportPhoto(src, src,
                type: 'source', captureId: s.captureId));
      } else {
        sourceMissing.add(s.id);
      }
      rows.add(map);
      continue;
    }

    // ── 旧レコード ──
    final area = _legacyArea(s);
    final collector = s.collectorId.isEmpty ? 'legacy' : s.collectorId;
    final ts = _legacyTimestamp(s.get('採集日時'));

    // 撮影イベント単位のグループキー（写真ID → 元写真名 → 行番号の順で決める）。
    final groupKey = s.get('写真ID').isNotEmpty
        ? 'pid:${s.get('写真ID')}'
        : (s.sourceFileName.isNotEmpty ? 'src:${s.sourceFileName}' : 'row:$i');
    String captureId;
    final cached = groupCaptureId[groupKey];
    if (cached != null) {
      captureId = cached;
    } else {
      final base = '$area-$collector-$ts';
      captureId = base;
      var n = 2;
      while (usedCaptureIds.contains(captureId)) {
        // 同秒の別撮影イベントと衝突 → 安定短序号を追加（-002, -003, …）。
        captureId = '$base-${n.toString().padLeft(3, '0')}';
        n++;
      }
      usedCaptureIds.add(captureId);
      groupCaptureId[groupKey] = captureId;
    }

    // suffix（同一 CaptureID 内で一意にする）。
    var suffix = s.cropSuffix.isEmpty ? 'a' : s.cropSuffix;
    var newSignId = '$captureId-$suffix';
    var n = 2;
    while (usedSignIds.contains(newSignId)) {
      newSignId = '$captureId-$suffix$n'; // a → a2 → a3 …
      n++;
    }
    usedSignIds.add(newSignId);
    final actualSuffix = newSignId.substring(captureId.length + 1);

    // 写真の写像（本地は旧名のまま、導出包内だけ新名で複製する）。
    final localCrop = s.fileName;
    var newCrop = '';
    if (localCrop.isNotEmpty) {
      newCrop = '$captureId-$actualSuffix.jpg';
      photoByZip[newCrop] = ExportPhoto(newCrop, localCrop,
          type: 'crop', captureId: captureId, signId: newSignId);
    }
    // 元写真: 旧・全景写真ファイル名 があれば -source.jpg として複製。
    // 無い（旧の整図採集は裁切=原図で全景欄が空）場合は捏造せず空のまま、
    // sourceMissing として manifest に明示する。
    final localSource = s.sourceFileName;
    var newSource = '';
    if (localSource.isNotEmpty && localSource != localCrop) {
      newSource = '$captureId-source.jpg';
      photoByZip.putIfAbsent(
          newSource,
          () => ExportPhoto(newSource, localSource,
              type: 'source', captureId: captureId));
    } else {
      sourceMissing.add(newSignId);
    }
    normalizedLegacy.add({
      'signId': newSignId,
      'legacySignId': s.id,
      'captureId': captureId,
    });

    map['CaptureID'] = captureId;
    map['SignID'] = newSignId;
    map['DisplayID'] = s.get('DisplayID').isNotEmpty
        ? s.get('DisplayID')
        : (s.id.isNotEmpty
            ? s.id
            : '$area-${_legacyDate(s.get('採集日時'))}'
                '-${_legacySeq(s).toString().padLeft(3, '0')}-$actualSuffix');
    map['採集者ID'] = collector;
    map['地区コード'] = area;
    if (s.get('LocalSeq').isEmpty) map['LocalSeq'] = _legacySeq(s);
    map['CropSuffix'] = actualSuffix;
    if (s.get('CropRect').isEmpty) {
      map['CropRect'] = '{"x":0,"y":0,"w":1,"h":1}';
    }
    // 写真ID は旧値のまま残す（本地ファイルへの追跡用）。
    map['写真ファイル名'] = newCrop;
    map['元写真ファイル名'] = newSource;
    map['全景写真ファイル名'] = newSource;
    if (s.get('DataStatus').isEmpty) {
      map['DataStatus'] = dataStatusFor(s.status);
    }
    rows.add(map);
  }

  final photos = photoByZip.values.toList()
    ..sort((a, b) => a.zipName.compareTo(b.zipName));
  return NormalizedExport(rows, photos, sourceMissing, normalizedLegacy);
}

/// 地区コード: 地区コード字段 → SignID/写真ID の先頭セグメント → 'UNK'。
String _legacyArea(Sign s) {
  final field = s.get('地区コード');
  if (field.isNotEmpty) return field.toUpperCase();
  for (final id in [s.id, s.get('写真ID')]) {
    final head = id.split('-').first;
    if (RegExp(r'^[A-Za-z]{2,5}$').hasMatch(head)) return head.toUpperCase();
  }
  return 'UNK';
}

/// 採集日時 'YYYY-MM-DD HH:MM:SS' → 'YYMMDDHHMMSS000'（秒精度なのでミリ秒は 000）。
/// 解析不能なら全ゼロ（一意性は呼び出し側の衝突回避 -00N が担保する）。
String _legacyTimestamp(String captured) {
  final digits = captured.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 14) return '${digits.substring(2, 14)}000';
  if (digits.length >= 8) {
    // 日付のみ（時刻欠落）→ 時刻部はゼロ埋め。
    return '${digits.substring(2, 8)}000000000';
  }
  return '000000000000000';
}

/// 採集日時 → 'YYYYMMDD'（DisplayID 生成用）。無ければ '00000000'。
String _legacyDate(String captured) {
  final digits = captured.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 8 ? digits.substring(0, 8) : '00000000';
}

/// LocalSeq: 字段 → 旧 SignID の 'SNNN' セグメント → 旧 写真ID の末尾数字 → 0。
int _legacySeq(Sign s) {
  final field = int.tryParse(s.get('LocalSeq'));
  if (field != null) return field;
  for (final seg in s.id.split('-')) {
    final m = RegExp(r'^S(\d{1,4})$').firstMatch(seg);
    if (m != null) return int.parse(m.group(1)!);
  }
  final pid = s.get('写真ID').split('-');
  if (pid.isNotEmpty) {
    final tail = int.tryParse(pid.last);
    if (tail != null) return tail;
  }
  return 0;
}
