# 更新履歴 (CHANGELOG)

バージョンは **MAJOR.MINOR.PATCH**（例 `v1.2.6`）。
- PATCH（末尾）= 小さな修正・調整
- MINOR = 目立つ新機能のまとまり
- MAJOR = 大きな節目／方向転換

APK 成果物のファイル名もこれに合わせる（例 `dist/LLMap-v1.2.6-release.apk`）。
Android の versionCode（`+N`）は番号表記に関わらず単調増加させる。

> 採番方針の変更（2026-06-30）: 初期は小変更ごとに MINOR を上げて v1.9 まで進んだため、
> 3 つの節目（MVP / ローカル化+AI / Lingscape UI 刷新）に整理し直した。過去の見出しは
> 新スキームで振り直している。

## v1.6.0 (2026-07-04) — LLMap Dataset Package v1.0（標準导出包 / Step 2）

导出を標準 Dataset Package に刷新（`dataset_package.dart` 新設・`store.buildBundle` 改修）。
将来の Research Console はこの包をそのまま取り込む。

### 包構造（`llmap_dataset_YYYYMMDD_HHMMSS.zip`）
- `data.csv`（規範化済み・36列）/ `photos/`（裁切図）/ `source_photos/`（元写真、
  CaptureID 毎に1枚・複数 sign 共有時も重複同梱しない）
- `metadata.json`（導出日時・件数・app/schema/format 版・欠落数）
- `schema.json`（headers / systemFields / fieldGroups(A〜D) / enums /
  statusValues / dataStatusMap / multiFields — Console が字段構成を解釈できる）
- `manifest.json`（**機械可読の主フォーマット**: files に path/type/signId/
  captureId/sizeBytes/localName、missingFiles・sourceMissing・
  normalizedLegacyRecords を記録）＋ `MANIFEST.txt`（人向け補助）＋ `README.md`
- 写真欠落・元写真なしでも导出は失敗せず manifest.json に記録。包内同名上書きなし。

### 互換に関する注記
- **导出入口は従来どおり1つ**（メニュー→データ导出）。导出フォーマットは旧
  `llmap_export.zip`（data.csv＋photos/＋MANIFEST.txt）から Dataset Package に
  **置き換え**（旧簡易形式は廃止。CSV 列は上位互換、写真が photos/ と
  source_photos/ に分かれる点のみ構造変更）。
- 旧データの導出時規範化（v1.5.1）はそのまま適用。本地データは不変。
- 規範化・包生成は純ロジック（export_normalizer / dataset_package）に分離し、
  単体テスト `test/dataset_package_test.dart` を追加。

## v1.5.1 (2026-07-04) — データ契約の験収と補完（Step 1.5）

### 溯源字段の追加（`models.dart` / `schema_defaults.dart` / 後端 `schema.py`）
- 新CSV列: `EntryMode`（採集方式、現行フローは `standard`）/ `DataStatus`
  （Console 審核状態: raw/ai_drafted/reviewed/verified、`_status` と対応）/
  `SchemaVersion`（データ契約版 `1.5`）/ `AppVersion`（採集時のアプリ版）。
- `Sign.setStatus()` を新設し、`_status` の全遷移箇所（AI下書・校閲・編集）で
  DataStatus を同時更新。旧レコードは空のままでよい（導出時に補完）。

### 導出時規範化（`export_normalizer.dart` 新設 / `store.buildBundle`）
- 旧レコードも导出の瞬間に新契約形式へ変換（**本地の project.json・旧写真は不変**）:
  `CaptureID = AREA-legacy-YYMMDDHHMMSS000`（採集者ID 無しは `legacy` 固定、
  端末の現IDは入れない）。同一 写真ID の裁切群は CaptureID・元写真を共有。
- 旧写真は导出包内でのみ新名（`CaptureID-<suffix>.jpg` / `-source.jpg`）に複製し、
  CSV の 写真ファイル名/元写真ファイル名 と zip 内容を完全一致させる。
- 同秒衝突は `-002` 序号で回避（导出包内の同名上書きなし）。旧・整図採集など
  元写真が無いレコードは 元写真ファイル名 空＋MANIFEST の `source_missing:` に明示。
- 単体テスト `test/export_normalizer_test.dart` を追加（旧単体/裁切群/同秒衝突/
  整図/壊れた記録/新旧混在/setStatus 同期）。

## v1.5.0 (2026-07-04) — A区域ID刷新（CaptureID / 多人採集で衝突しない命名）

多人採集・データ合并・将来の PC Console 取り込みに向けて、識別字段と写真命名を
「地区＋日付＋連番」依存から **CaptureID 中心**に刷新（詳細は `docs/data-contract.md`）。

### 新ID契約（`imaging.dart` / `crop_screen.dart` / 後端 `schema.py`）
- **CaptureID** `AREA-COLLECTORID-YYMMDDHHMMSSmmm` を新設（1回の撮影イベントの一意ID）。
  Settings の既存ランダム CollectorID（NanoID 8桁）＋ミリ秒時刻を含むため、
  複数人が同日同地区で採集しても写真ファイル名 / SignID が衝突しない。
- **SignID** = `CaptureID-suffix`、**写真ファイル名** = `CaptureID-<suffix>.jpg`、
  **元写真ファイル名** = `CaptureID-source.jpg`（原始完整写真。pano 呼称は廃止）。
- **DisplayID** `AREA-YYYYMMDD-SEQ-suffix` は表示専用（主キーにしない）。
  一覧/画廊/地図は短いラベル `OOK #008-a` を表示し、長い CaptureID を出さない。
- 新CSV列: `CaptureID / DisplayID / 採集者ID / 地区コード / LocalSeq / CropSuffix /
  CropRect / 元写真ファイル名`。**CropRect** は框选矩形を JSON（相対座標）で保存
  — 框选なしは `{"x":0,"y":0,"w":1,"h":1}`。PC 端の再裁切の土台。
- 旧列 `写真ID / 全景写真ファイル名` は保持（新規レコードでは 写真ID=CaptureID、
  全景写真ファイル名=元写真ファイル名 の互換値を書き込む）。

### 旧データ互換
- 旧レコードは無変換のまま閲覧・編集・导出可。読取側フォールバック:
  CaptureID→写真ID / DisplayID→SignID / 元写真→全景写真 / CropSuffix→SignID末尾。

### 写真保存の衝突保護（`store.dart`）
- `savePhoto` が実際に保存した名前を返すように。同名同内容はスキップ、
  同名異内容は `名前~2.jpg` の衝突回避名で保存（静黙上書きを廃止）。
- 导出 ZIP の写真収集に `元写真ファイル名` を追加。

### UI
- 編集画面に**識別情報カード**（展開で SignID/CaptureID/DisplayID/写真・元写真
  ファイル名/採集者ID/地区コード/採集日時/緯度/経度 を全表示・コピー可）。

## v1.4.0 (2026-06-30) — 採集字段の刷新（三語重構版 v3 / Scollon・Reh 準拠）

採集字段定義表を「三語重構版 v3」へ全面刷新。**採集從寬・分析從嚴**の方針で、
現場で客観判定しやすい字段に整理し直した（純減 6 字段・新規 4 字段）。

### CSV 構造（`schema_defaults.dart` / 後端 `schema.py`）
- **削除（6）**: `来源類型`・`視認等級`・`位置描述`・`想定受容者`（読心/重複/不可検証）と、
  旧 `装飾的言語`→`装飾の言語` へ改称。`判定来源`は `_status` に統合。
- **新規（4）**: `文字性`（含文字/純記号/対象外の第一軸）・`文字体系/Script`（書記体系を言語と分離）・
  `空間階層`（低位/中位/高位＝権力·可及性軸）・`重ね書き/Layering`（時間的上書き痕跡）。
- **更新**: `設置主体`を細分（行政·公共機関/商業·チェーン/商業·個人店/個人/団体/不明）、
  `ディスコース類型`を新設（規約/基礎設施/商業/越境/判読不能/その他＝Scollon 2003、判定順あり）、
  `多言語関係`を Reh(2004) 類型へ（単言語/複製/重複/部分翻訳）、`可読性`を物理的明瞭度のみに収窄。
- **言語値**を拡張（日本語/韓国語/中国語/ベトナム語/ネパール語/英語/その他）。地図色も追従。
- **ステータス**: `pending / ai / human-reviewed / final`（旧 `modified/reviewed` を改め、判定来源を内包）。

### AI プロンプト（`ai.dart` / 後端 `ai.py`）
- システムプロンプトを刷新（言語景観研究者として「採集從寬」で**下書き**、推測は備考に根拠、
  読めない言語でも文字体系は判定、内容判定字段は「判読不能」出口）。
- 字段ガイドを全 16 字段に作り直し、各字段の選択肢＋境界判定ルール
  （支配性の優先順位／ディスコースの判定順／補助 vs 装飾の区別口訣 等）を埋め込み。
  AI は全編集字段（名称含む）を下書きし、人が校閲して `human-reviewed/final` へ。

### 複数選択 ＋ 自由追加
- `主要言語`・`補助言語`・`装飾の言語`・`文字体系` を**複数選択**化（チップ式 multi-select）。
  選択肢に無い値は入力欄から**自由追加**できる。値は「/」区切りで保存（例「日本語/韓国語」）。
- `文字体系` の選択肢を更新: 漢字/平仮名/片仮名/ローマ字/ハングル/**デーヴァナーガリー/ビルマ文字/タイ文字/ベンガル文字**/アラビア/キリル/その他/無。
- 地図ピン色・画廊タグ・言語フィルタを併記値（"/"）対応に（代表言語で配色、フィルタは含有判定）。

### 採集者ID（多人協作）
- 設定に**採集者ID**を追加。SignID を「地点-採集者-序号」（例 `HAS-K7m9Qp4t-S001-a`）にし、
  多人で同時採集しても採番が衝突しない。
- 既定で**自動生成**（NanoID 8桁、視認・手抄・スキャンで紛れやすい `0/O/1/l/I` を除外）。
  設定で自由に変更・再生成できる（`SharedPreferences` に保存）。

### UI 追従
- 画廊の二次フィルタを `来源類型`→`設置主体` に、地図詳情の項目を `来源類型`→`ディスコース類型` に差替え。
  ラベルは三言語（设置/設置/Agent・话语类型/ディスコース類型/Discourse type）を更新。
- 編集で status を `human-reviewed` に昇格するよう分層ロジックを更新。
- 編集画面に**写真プレビュー**（タップで全画面ズーム）、采集記録カードに**サムネイル**（番号バッジ付）を追加。
- 既定の地点コードを `OOK`（新大久保 Shin-Ōkubo）に変更。

> データ移行: 旧スキーマで保存済みの記録は Map 構造のため起動・表示は壊れないが、
> 削除字段は CSV 書き出し対象外、新字段は空欄になる。再AI識別または手動で補完する。

## v1.3.1 (2026-06-30) — 導出の固まり修正（実機）

- 実機（Xiaomi）で「导出を押すと一瞬固まり、進捗ダイアログが点滅／フリーズして
  そのまま共有画面へ」だった不具合を修正。
- 原因: ZIP 圧縮（deflate）がメインスレッドで動き UI をブロックしていた。
- 対応: `LocalStore.buildBundle` の圧縮を **別アイソレート**へ移し、進捗を
  `ReceivePort` で受信。UI スレッドが空くため進捗バーが滑らかに動く。
  大量画像でも UI が固まらない。

## v1.3.0 (2026-06-30) — 多言語対応（简体中文 / 日本語 / English）

- Flutter 公式の `flutter_localizations` + ARB（gen-l10n）で国際化。
  `lib/l10n/app_{en,zh,ja}.arb` に全UI文言を集約、`AppLocalizations` を生成。
- **言語切替**: 既定はシステム言語に追従。設定画面に言語ピッカー
  （跟随系统 / 简体中文 / 日本語 / English）を追加し、`SharedPreferences` に保存。
  `localeNotifier` を `MaterialApp` が購読し即時切替。
- 全画面・全部品の表示文言をローカライズ（起動/撮影/ホーム/框选/字段/編集/設定/
  画廊/Select Location/地図/各ダイアログ/進捗）。
- **据え置き（データ層は不変）**: CSV 標準の字段名・分類値（主要言語/日本語 等）は
  研究用の正準キーのため未翻訳。状態コード（pending/ai/…）も据え置き。必要なら次段で
  表示ラベルのマップを追加可能。

## v1.2.7 (2026-06-30) — 導出進捗の視認性改善

- 少量（数枚）でも進捗ダイアログが見えるよう、**最低表示時間 ~0.9 秒**を確保。
  以前は5枚程度だと一瞬で閉じて進捗バーが見えなかった。
- 完了時に**「✓ 完成 · 共 N 张照片」**と緑のバーを表示してから閉じるように。

## v1.2.6 (2026-06-30) — 采集档案（筛选型画廊）

- 新規 `lib/screens/gallery_screen.dart`: 缩略图カード网格で採集記録を閲覧する
  全屏「采集档案」ページ。
  - 各カード: 裁切写真の缩略图＋状態バッジ＋名称＋SignID＋言語タグ（言語別色）＋来源タグ。
  - **筛选**: 言語 × 来源（横スクロールのチップ）。响应式网格（`SliverGridDelegate`、
    最大列幅220）、`GridView.builder` で遅延読込（大量でも軽量）。
  - タップで `EditSignScreen` 編集。
- 地図主体ホームの「采集记录」パネルヘッダに**画廊入口**（grid アイコン）を追加。
  底部抽屉の快速列表はそのまま保持。
- **状態オーナーは HomeScreen のまま**。画廊の編集/削除は callback で委譲し、
  `_signs`/`LocalStore` のデータフローは不変。

## v1.2.5 (2026-06-29) — 導出の進捗表示

- **導出進捗ダイアログ**を追加。写真1枚ごとに「X / N 张照片」を表示（新規 `LLProgressDialog`）。
- `LocalStore.buildBundle` を **`ZipFileEncoder` のストリーミング書き込み**に変更
  （全画像をメモリに抱えず、写真ごとに進捗 `onProgress(done,total)` を通知）。

## v1.2.4 (2026-06-29) — 地図の体感改善（実機フィードバック）

- **ズーム時の灰白点滅を軽減**: タイルの `keepBuffer`/`panBuffer` を増やし、
  未読込領域の下地を暖色(`muted`)へ。
- **起動時に現在地をプレビュー**: 起動と同時にGPS取得、地図準備完了時に現在地へ
  センタリング（取得不可なら記録範囲）。`LLMapView` に `onMapReady` を追加。

## v1.2.3 (2026-06-29) — 仕上げ（Phase 6）

- 起動画面をブランド化＋中文化。撮影シートを中文＋LL化（`LLBottomSheetScaffold`）。
- 衛星/暗色地図での出典表記を半透明チップ化。残存日本語のユーザー可視文言を中文へ。

## v1.2.2 (2026-06-29) — Select Location 手動微調整（Phase 5）

- 新規 `lib/screens/select_location_screen.dart`: 中心固定ピン方式の位置選択
  （地图/卫星切替・重新定位・恢复自动定位・座標表示）。
- `CropScreen`: GPS状態行に手動調整入口。`_manualGps` を優先適用
  （`gps = _manualGps ?? await _gpsFuture`）。採集ロジックは不変。

## v1.2.1 (2026-06-29) — 既存画面の視覚移行（Phase 4）

- `CropScreen`/`FieldsScreen`/`EditSignScreen`/`SettingsScreen` を LL コンポーネント＋
  tokens に移行、中文文案へ統一。`SignForm` 補助文字を tokens に。
- `box_selector.dart`: ハードコード色を `AppColors` に置換。
- **業務ロジック・データ構造は不変。**

## v1.2.0 (2026-06-29) — Lingscape UI 全面刷新 ＋ 地図主体ホーム（Phase 1–3）

Figma「Lingscape」を参照し、エディトリアル調＋map-first へ全面刷新。中核データフロー
（`_signs`/`LocalStore`/`Sign`/`AppSchema`）は不変。中文文案へ統一。

### デザインシステム
- `lib/theme/tokens.dart`: `AppColors`/`AppSpacing`/`AppRadius`/`AppShadows`/`AppText`
  （Fraunces/Nunito）/`parseHexColor`。`theme.dart` は tokens 参照に再編（`llXxx` は互換維持）。
- 共通部品 `lib/widgets/ll/`: `LLPrimaryButton`/`LLSecondaryButton`/`LLIconButton`/`LLCard`/
  `LLTagChip`/`LLSegmentedControl`/`LLAppHeader`/`LLBottomSheet`/`LLDialog`/`LLFormField`。

### 地図主体ホーム
- 地図部品を抽出・再利用化 `lib/widgets/map/`: `LLMapView`（CARTO/Esri 衛星切替）・
  `LLMapDetailCard`・`LLMapLegend`・`MapPin`。`MapScreen` も同部品へ置換。
- `HomeScreen` を地図主体に再構成（上部ヘッダ＋Map/卫星＋现在位置＋「新增采集」＋
  採集記録の常駐ドラッグ抽屉）。本地保存成功 Dialog、Info メニューを追加。

### アプリアイコン
- Lingscape のアプリマークに刷新（Pillow で SVG 描画、`flutter_launcher_icons` で展開）。

### 依存追加
- `google_fonts` / `flutter_launcher_icons`(dev)

## v1.1.0 (2026-06-29) — ローカル完結化（計画C-1）＋ AI端末化

「家のPCを切ったまま外でスマホ単体で採集・閲覧・書き出し・AI判定まで完結」を実現。

- **データ永続化**: 採集記録と写真を端末に保存、再起動後も復元（`lib/store.dart`）。
- **オフライン起動**: 端末内既定スキーマ（`lib/schema_defaults.dart`）。
- **ローカル採集/書き出し**: クロップ・SignID採番・CSV/ZIP を端末内で（`lib/imaging.dart`）。
- **AI端末化**: Claude/Gemini を端末から直接HTTP（`lib/ai.dart`）。APIキーは端末内保存。
- ビルド: ASCII パス化で直接ビルド可、`kotlin.incremental=false` でキャッシュ失敗回避。

## v1.0.0 — 初期リリース

- Phase 0〜3: FastAPI後端（EXIF/GPS・AI判定・CSV）、Flutter採集MVP、地図预览、AI填字段。
- 実機カメラ撮影・実時GPS、編集/削除、CSV+写真の一括エクスポート。後端依存の構成。
