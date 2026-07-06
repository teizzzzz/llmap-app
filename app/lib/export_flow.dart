/// Dataset Package 導出の共通フロー（Step 14 で home_screen から抽出）。
/// 進捗ダイアログ → buildBundle → 共有(モバイル)/Downloads 保存(デスクトップ)。
/// Home（全部/未分類/分類済み）と Gallery（表示/選択/相册）の両方が使う。
/// 導出包の構造・写真の収束は store.buildBundle / export_normalizer のまま。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'capture.dart' show isMobile;
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'store.dart';
import 'widgets/ll/ll.dart';

/// [signs] を Dataset Package として書き出す。空リストは何もしない
/// （範囲選択側で noRecordsToExport を先に案内する）。
Future<void> runDatasetExport(
  BuildContext context, {
  required List<Sign> signs,
  required AppSchema schema,
}) async {
  if (signs.isEmpty) return;
  final t = AppLocalizations.of(context);
  final progress = ValueNotifier<({int done, int total})>((done: 0, total: 0));
  final sw = Stopwatch()..start();
  // 進捗ダイアログは1回だけ閉じる（success と catch の二重 pop で
  // 本体ページまで pop してしまい黒画面になるのを防ぐ）。
  var dialogOpen = true;
  void closeDialog() {
    if (dialogOpen && context.mounted) {
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => LLProgressDialog(
      title: t.exporting,
      unit: t.unitPhotos,
      progress: progress,
    ),
  );
  try {
    final zipPath = await LocalStore.instance.buildBundle(
      signs,
      schema,
      onProgress: (done, total) => progress.value = (done: done, total: total),
    );
    // 少量でも進捗→完成が見えるよう、最低 ~0.9 秒は表示する。
    final remain = 900 - sw.elapsedMilliseconds;
    if (remain > 0) {
      await Future.delayed(Duration(milliseconds: remain));
    }
    if (!context.mounted) return;
    closeDialog(); // 進捗ダイアログを閉じる
    if (isMobile) {
      // iPad では sharePositionOrigin 必須（無いと presentation で例外）。
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(zipPath)],
        text: 'LLMap',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.datasetExported)));
      }
    } else {
      final dir =
          Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
      final zipName = zipPath.split(RegExp(r'[/\\]')).last;
      final dest = File('$dir/Downloads/$zipName');
      await dest.parent.create(recursive: true);
      await File(zipPath).copy(dest.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.exportedTo(dest.path))),
        );
      }
    }
  } catch (e) {
    closeDialog(); // 進捗ダイアログを閉じる（まだ開いていれば）
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.exportFailed('$e'))));
    }
  } finally {
    progress.dispose();
  }
}

/// 件数つきの導出確認ダイアログ。OK なら true。
Future<bool> confirmDatasetExport(BuildContext context, int count) async {
  final t = AppLocalizations.of(context);
  if (count == 0) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.noRecordsToExport)));
    return false;
  }
  final ok = await showLLDialog<bool>(
    context,
    icon: Icons.ios_share,
    title: t.exportConfirmTitle(count),
    message: t.exportConfirmBody,
    primaryLabel: t.exportAction,
    onPrimary: () => Navigator.pop(context, true),
    secondaryLabel: t.cancel,
    onSecondary: () => Navigator.pop(context, false),
  );
  return ok == true;
}
