/// Dataset Package 導出の共通フロー（Step 14 で home_screen から抽出）。
/// 進捗ダイアログ → buildBundle → 共有(モバイル)/Downloads 保存(デスクトップ)。
/// Home（全部/未分類/分類済み）と Gallery（表示/選択/相册）の両方が使う。
/// 導出包の構造・写真の収束は store.buildBundle / export_normalizer のまま。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'albums.dart';
import 'capture.dart' show isMobile;
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'record_ops.dart';
import 'store.dart';
import 'theme/tokens.dart';
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
  // 進捗ダイアログの操作は NavigatorState 経由で行う:
  // 呼び出し元（Gallery 等）が導出中に unmount されても、ダイアログ自体は
  // root navigator 上に生きているため、context ではなく nav で確実に閉じる。
  final nav = Navigator.of(context, rootNavigator: true);
  // 進捗ダイアログは1回だけ閉じる（success と catch の二重 pop で
  // 本体ページまで pop してしまい黒画面になるのを防ぐ）。
  var dialogOpen = true;
  void closeDialog() {
    if (dialogOpen && nav.mounted) {
      dialogOpen = false;
      nav.pop();
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    // Android の戻るボタン/ジェスチャでも閉じさせない（barrierDismissible は
    // 障壁タップしか防がない）。途中で dialog だけ pop されると、完了時の
    // closeDialog() が下の画面を誤って pop してしまうため。
    builder: (_) => PopScope(
      canPop: false,
      child: LLProgressDialog(
        title: t.exporting,
        unit: t.unitPhotos,
        progress: progress,
      ),
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
    // ダイアログは呼び出し元の生死に関わらず必ず閉じてから、共有/保存へ。
    closeDialog();
    if (!context.mounted) return;
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

/// 確認 → 実行の一連（Home / Gallery 共通。導出は非破壊）。
Future<void> confirmAndRunDatasetExport(
  BuildContext context, {
  required List<Sign> signs,
  required AppSchema schema,
}) async {
  if (!await confirmDatasetExport(context, signs.length)) return;
  if (!context.mounted) return;
  await runDatasetExport(context, signs: signs, schema: schema);
}

/// 相册を1つ選んで導出する二段目シート（件数つき）。Home / Gallery 共通。
/// 件数ラベルと実際の導出対象は**同じ** exportCandidates の結果を使う
/// （表示と中身が食い違わないように、相册ごとに1回だけ計算する）。
void showAlbumExportPicker(
  BuildContext context, {
  required List<Album> albums,
  required List<Sign> allSigns,
  required AppSchema schema,
}) {
  final t = AppLocalizations.of(context);
  showLLBottomSheet(context, title: t.exportPickAlbum, children: [
    for (final a in albums)
      () {
        final candidates = exportCandidates(
          scope: ExportScope.album,
          allSigns: allSigns,
          currentAlbum: a,
        );
        return LLSheetTile(
          icon: Icons.photo_album_outlined,
          label: '${a.name} (${candidates.length})',
          onTap: () {
            Navigator.pop(context);
            confirmAndRunDatasetExport(context,
                signs: candidates, schema: schema);
          },
        );
      }(),
    LLSheetTile(
        icon: Icons.close,
        label: t.cancel,
        color: AppColors.textSecondary,
        showChevron: false,
        onTap: () => Navigator.pop(context)),
  ]);
}
