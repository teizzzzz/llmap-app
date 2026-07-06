import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/l10n/app_localizations.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/screens/gallery_screen.dart';
import 'package:llmap_app/widgets/ll/ll.dart';

AppSchema _schema() => AppSchema(
      csvHeader: const ['SignID', '名称', '主要言語'],
      statusValues: const ['pending', 'reviewed'],
      enums: const {},
      aiFields: const [],
      languageColors: const {'日本語': '#2e6fdb'},
    );

// 写真ファイル名は空にして file IO を避ける（thumb は fallback 表示）。
Sign _sign(String id, String name, String capturedAt) => Sign({
      'SignID': id,
      '名称': name,
      '主要言語': '日本語',
      '採集日時': capturedAt,
      '_status': 'pending',
    });

void main() {
  testWidgets('長押しで選択モード → 多選 → 全選 → 批量削除（確認つき）',
      (tester) async {
    final signs = [
      _sign('A-1', '記録い', '2026-07-01 10:00:00'),
      _sign('A-2', '記録ろ', '2026-07-02 10:00:00'),
      _sign('A-3', '記録は', '2026-07-03 10:00:00'),
    ];
    final deleted = <Sign>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GalleryScreen(
          signs: signs,
          schema: _schema(),
          onDeleteMany: (list) async {
            deleted.addAll(list);
            signs.removeWhere(list.contains); // Home 側の削除を模擬
          },
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsNWidgets(3));

    // 1) 長押しで選択モードへ（その項目が選択済みで開始）
    await tester.longPress(find.byType(LLCard).first);
    await tester.pumpAndSettle();
    expect(find.text('1 件選択中'), findsOneWidget);

    // 2) 選択モード中のタップは開閉ではなく選択の増減
    await tester.tap(find.byType(LLCard).at(1));
    await tester.pumpAndSettle();
    expect(find.text('2 件選択中'), findsOneWidget);

    // タップで選択解除もできる
    await tester.tap(find.byType(LLCard).at(1));
    await tester.pumpAndSettle();
    expect(find.text('1 件選択中'), findsOneWidget);

    // 3) 全選
    await tester.tap(find.text('すべて選択'));
    await tester.pumpAndSettle();
    expect(find.text('3 件選択中'), findsOneWidget);

    // 4) 批量削除 → 確認ダイアログ → 実行
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('3 件の記録を削除しますか？'), findsOneWidget);
    expect(find.text('この操作は取り消せません。'), findsOneWidget);
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(deleted.length, 3);
    expect(find.text('まだ記録がありません'), findsOneWidget); // 空状態
  });

  testWidgets('キャンセルで選択モードを抜ける / Select ボタンは空選択で開始',
      (tester) async {
    final signs = [
      _sign('B-1', 'その一', '2026-07-01 10:00:00'),
      _sign('B-2', 'その二', '2026-07-02 10:00:00'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GalleryScreen(
          signs: signs,
          schema: _schema(),
          onDeleteMany: (_) async {},
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select ボタン → 0 件選択で開始
    await tester.tap(find.text('選択'));
    await tester.pumpAndSettle();
    expect(find.text('0 件選択中'), findsOneWidget);

    // キャンセル（×）で通常モードへ戻る
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('採集アーカイブ'), findsOneWidget); // 通常タイトル復帰
  });

  testWidgets('筛选（言語チップ）で表示が絞られ、クリアで戻る', (tester) async {
    final signs = [
      _sign('C-1', '日本語の記録', '2026-07-01 10:00:00'),
      Sign({
        'SignID': 'C-2',
        '名称': '韓国語の記録',
        '主要言語': '韓国語',
        '採集日時': '2026-07-02 10:00:00',
        '_status': 'pending',
      }),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GalleryScreen(
          signs: signs,
          schema: _schema(),
          onDeleteMany: (_) async {},
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 件を表示'), findsOneWidget);

    // 筛选シートを開いて「韓国語」を選ぶ（即時反映）
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('韓国語').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(find.byType(LLCard), findsOneWidget);
    expect(find.text('1 件を表示'), findsOneWidget);

    // クリアで全件へ戻る（記録本体は変わらない）
    await tester.tap(find.text('絞り込みをクリア'));
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsNWidgets(2));
    expect(signs.length, 2);
  });

  testWidgets('归納状態視図: 既定は未分類 → 加入相册で即時消失 → All/Filed → 相册視図は独立',
      (tester) async {
    final signs = [
      _sign('D-1', '整理対象', '2026-07-01 10:00:00'),
      _sign('D-2', '未整理のまま', '2026-07-02 10:00:00'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GalleryScreen(
          signs: signs,
          schema: _schema(),
          onDeleteMany: (_) async {},
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1) 既定 = 未分類（segmented 表示・相册ゼロなので全件が未分類）
    expect(find.text('未分類'), findsOneWidget);
    expect(find.byType(LLCard), findsNWidgets(2));
    expect(find.text('2 件を表示'), findsOneWidget);

    // 2) 相册を新規作成（UI 経由）
    await tester.tap(find.text('+ 新規アルバム'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'テスト相册');
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(find.text('テスト相册 (0)'), findsOneWidget);

    // 3) D-1 を選択して相册へ → 未分類から即時消失
    await tester.longPress(find.text('整理対象'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_album_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テスト相册')); // 追加先シートの行
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close)); // 選択モード終了
    await tester.pumpAndSettle();
    expect(find.text('整理対象'), findsNothing); // 未分類視図から消えた
    expect(find.text('未整理のまま'), findsOneWidget);
    expect(find.text('1 件を表示'), findsOneWidget);

    // 4) すべて = 2 件 / 分類済み = 1 件
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsNWidgets(2));
    await tester.tap(find.text('分類済み'));
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsOneWidget);
    expect(find.text('整理対象'), findsOneWidget);

    // 5) 相册視図は归納状態と無関係に表示・segmented は隠れる
    await tester.tap(find.text('テスト相册 (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsOneWidget);
    expect(find.text('未分類'), findsNothing); // segmented 非表示

    // 6) 相册から外す → 相册は空 → 主視図の未分類に戻る
    await tester.longPress(find.text('整理対象'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('このアルバムにはまだ記録がありません。'), findsOneWidget);

    await tester.tap(find.text('すべての記録'));
    await tester.pumpAndSettle();
    // 直前の状態（分類済み）が維持され、いまは分類済みゼロ → 専用空状態
    expect(find.text('分類済みの記録はありません'), findsOneWidget);
    expect(find.text('記録をアルバムに追加すると、ここに表示されます'), findsOneWidget);
    await tester.tap(find.text('未分類'));
    await tester.pumpAndSettle();
    expect(find.byType(LLCard), findsNWidgets(2)); // 全員未分類に戻った
  });
}