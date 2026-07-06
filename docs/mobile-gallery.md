# Mobile Gallery 管理増強（Step 12 / 12.1 / 14）

手機端の采集档案（Gallery）を「相册 / 档案管理器」に近づける増強。
**app/（Flutter）のみ変更** — backend / Console / Desktop / Dataset Package v1 /
SignID・CaptureID・DisplayID / 写真ファイル名は一切変更しない。

## 機能

### 選択性導出（Step 14）

Dataset Package の導出前に**範囲を選ぶ**。導出包の構造（data.csv /
photos / source_photos / metadata / schema / manifest / README）は不変で、
**中身の記録と写真だけ**が範囲に従う。

```text
Home メニュー導出      → 全部 / 未分類 / 分類済み / アルバムから選ぶ…
Gallery 通常モード導出  → 現在の表示 / 現在のアルバム / 全部 / アルバムから選ぶ…（件数つき）
Gallery 選択モード導出  → 選択中の記録（0 件は無効）
```

「アルバムから選ぶ…」（`ExportScope.album`）は二段目シートで任意の相册を
件数つきで選ぶ。いま開いている相册に限らない。相册ゼロのときは非表示。

- 範囲は record_ops.dart の `ExportScope` + `exportCandidates()`（純ロジック）。
  「現在の表示」は Gallery の `_visible` をそのまま使い、過濾を再実装しない
  （CSV 行順は現在の排序に従う）。
- 実行は export_flow.dart の共通フロー（home から抽出。進捗ダイアログ →
  buildBundle → 共有/保存）。導出前に件数つき確認、空範囲は
  「書き出す記録がありません」。
- 写真は buildBundle が渡された記録から収束: 参照される crop / 元写真のみ
  同梱、共有元写真は 1 回だけ、欠図は manifest missingFiles（従来どおり）。
- 導出は非破壊: 記録・選択状態・相册所属を変えない。albums.json は
  導出包に入らない。

### 相册归納状態視図（Step 12.1）

Gallery 主視図の上部 segmented で「**未分類 / すべて / 分類済み**」を切替。
**既定は未分類** = どの相册にも属さない記録だけを表示する整理待ち Inbox。

```text
採集 → 未分類に現れる → 選択して相册へ → 未分類から即時消失
必要なら「すべて」「分類済み」「該当相册」で閲覧
全相册から外れた記録は未分類へ自動復帰（相册削除時も同様）
```

- 判定は `isFiled(sign, albums)`（いずれかの相册の recordIds に SignID がある）。
  純ロジックは record_ops.dart の `AlbumStatusFilter` / `applyAlbumStatusFilter`。
- **具体的な相册を開いている間は适用しない**（相册視図が優先。segmented も
  非表示にして混乱を避ける）。
- 既存の筛选・排序と叠加可能。複数相册所属でも「分類済み」に 1 回だけ表示。
- 空状態: 未分類空=「未分類の記録はありません」＋副文言、分類済み空=
  「分類済みの記録はありません」＋副文言。筛选起因の空は noMatch を優先。
- l10n: unfiled / filed / noUnfiledRecords / allRecordsFiled /
  noFiledRecords / recordsAddedToAlbumsAppearHere × ja/zh/en
  （「すべて」は既存 `all` キーを再利用）。

### 批量選択（iPhone 相册式）

- 通常モード: タップ=詳情編集、**長押し=選択モードに入りその項目を選択**
- 「選択」ボタンからは 0 件選択で開始
- 選択モード: タップで選択/解除、AppBar に「N 件選択中」＋
  すべて選択/選択解除・アルバム追加・（相册表示中は）アルバムから外す・削除
- ×（キャンセル）で通常モードへ復帰

### 批量削除と写真の安全策

- 削除前に必ず二次確認（「N 件の記録を削除しますか？」「この操作は取り消せません。」）
- 写真の削除は `record_ops.orphanedPhotos()` が計算する:
  **削除対象が参照し、かつ残る記録のどれからも参照されない**ファイルだけを消す。
  1枚の元写真から複数 sign を切り出した場合（1图多sign）、他の sign が
  生きている限り元写真は消さない。旧字段 `全景写真ファイル名` も参照として扱う。
- 実行経路は HomeScreen の `_deleteSigns()` に一本化
  （Gallery の批量削除・編集画面からの単発削除・首页 Dismissible すべて同じ）。
  従来は記録だけ消して写真ファイルが孤児として残っていた — 本 Step で解消。
- 順序は「記録を先に確定保存 → 写真を削除」。途中で落ちても
  「参照切れの写真が残る」側に倒れ、データは壊れない。

### 筛选（表示のみ・記録は不変）

`record_ops.GalleryFilter`。条件: 主要言語（併記は個別値に展開）/ 設置主体 /
EntryMode / DataStatus / 地区コード / 採集者ID / GPS有無 / 写真有無 / 元写真有無。
DataStatus 未併記の旧データは `_status` から導出して照合する。
筛选シートは即時反映・結果件数表示・クリアあり。選択肢は実データから生成する。

### 排序（表示のみ）

`record_ops.sortedSigns()`。採集日時 新しい順（既定）/ 古い順、DisplayID 昇順 / 降順。
採集日時が無い・解析できない旧データは**常に末尾**（崩れない）。

### 相册 / フォルダ（Phase 2）

- データ構造: `Album { id, name, createdAt, updatedAt, recordIds: [SignID] }`
  を `<docs>/llmap/albums.json` に保存（`LocalStore.loadAlbums/saveAlbums`）。
- 1記録は複数相册に所属可。相册名は SignID・ファイル名に**入れない**。
- **CSV / Dataset Package には入らない**（端末内の整理機能。導出フォーマット不変）。
- UI: Gallery 上部の相册バー（All Records / 各相册(件数) / ＋新規）。
  相册チップ長押しで改名・削除。選択モードから「アルバムに追加/外す」。
- 相册削除は相册本体のみ。中の記録・写真は消さない（確認文言にも明記）。
- 記録を削除した時は全相册の所属からも外して保存する。

## 多言語

ja / zh / en の 3 言語に 36 キー追加（選択・削除確認・排序・筛选・相册一式）。
`lib/l10n/app_*.arb` が正で、`flutter gen-l10n` により
`app_localizations_*.dart` を再生成済み。硬编码文案なし。

## テスト（flutter analyze / flutter test 実行済み）

本 Step からクラウド環境に Flutter SDK 3.44.4（Dart 3.12.2）を取得して
実行検証できるようになった:

- `flutter analyze`: 0 errors / 0 warnings（info 1 件は既存 imaging.dart の
  doc comment 表記のみ）
- `flutter test`: **47/47 通過**
  - `test/record_ops_test.dart`（新規）: 孤児写真計算（共有元写真の保護・
    最終参照者・批量・旧字段）、排序（新旧・欠損/破損日時は末尾・元リスト不変）、
    筛选（併記言語・状態導出・GPS/写真有無・clear）
  - `test/albums_test.dart`（新規）: 相册モデル（重複/空ID・複数所属・
    JSON 往復・壊れた要素の読み飛ばし・削除が記録に触れない構造）
  - `test/gallery_screen_test.dart`（新規 widget テスト）: 長押し→多選→
    全選→確認つき批量削除→空状態、キャンセル復帰、Select は空選択開始、
    筛选の即時反映とクリア
  - 既存テスト 30 件も通過（`map_screen_test` は localizations delegates 欠落で
    元から落ちる状態だったのを修正）

## 変更ファイル

```text
app/lib/record_ops.dart          新規（筛选・排序・孤児写真計算の純ロジック）
app/lib/albums.dart              新規（相册モデル＋JSON）
app/lib/store.dart               deletePhotos / loadAlbums / saveAlbums 追加
app/lib/screens/gallery_screen.dart  選択モード・筛选・排序・相册 UI（全面改修）
app/lib/screens/home_screen.dart     _deleteSigns（写真安全削除の共通経路）
app/lib/widgets/ll/ll_card.dart      onLongPress 対応
app/lib/l10n/*                       36 キー ×3言語（arb + 生成済み dart）
app/test/{record_ops,albums,gallery_screen}_test.dart  新規
```
