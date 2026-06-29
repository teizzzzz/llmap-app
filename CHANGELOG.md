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
