# 更新履歴 (CHANGELOG)

バージョン採番は v1.0 / v1.1 / v1.2 ... と進める。
APK 成果物のファイル名もこれに合わせる（例 `dist/LLMap-v1.1-release.apk`）。

## v1.4 (2026-06-29) — 既存画面の視覚移行（Phase 4）

採集フローの各画面を LL コンポーネント＋tokens に移行し、中文文案へ統一。
**業務ロジック・データ構造は不変。**

### 変更（視覚のみ）
- `CropScreen`: ヒントカード＋GPS状態表示（定位中／已获取／无法获取）、底部を
  `LLPrimaryButton`「下一步：填写字段」に。
- `FieldsScreen`: プレビューを `LLCard`、底部を `LLPrimaryButton`(暂存)＋
  `LLSecondaryButton`(保存本次采集)、AI識別中を `LLTagChip`「识别中…」に。
- `EditSignScreen`: 保存を `LLPrimaryButton`、削除確認を `LLDialog`(danger) に。
- `SettingsScreen`: `LLCard`＋`LLFormField` でセクション化、中文化。後端を「可选/进阶」に。
- `SignForm`: 補助文字・ID を tokens/`AppText` に。
- `box_selector.dart`: ハードコード色 `#c84b31`/`#27ae60` を
  `AppColors.accentTerracotta`/`success` に置換（Phase 6 項目を前倒し）。

### 据え置き（Phase 5–6）
- Select Location 手動微調整、空/エラー/ロード状態の最終統一、文案の残り精査。

## v1.3 (2026-06-29) — 地図主体ホーム＋デザインシステム整備（Phase 1–3）

Figma の map-first 方針に沿ってホームを地図主体へ。中核データフロー（`_signs`/
`LocalStore`/`Sign`/`AppSchema`）は不変。中文文案へ統一。

### Phase 1: デザイントークン
- 新規 `lib/theme/tokens.dart`: `AppColors`（backgroundWarm/surfaceIvory/accentBlue/
  Mustard/Terracotta/Violet/success/warning/danger 等）・`AppSpacing`・`AppRadius`・
  `AppShadows`・`AppText`（Fraunces/Nunito）・`parseHexColor`。
- `theme.dart` は tokens を参照する形へ再編（既存 `llXxx` は後方互換エイリアスとして維持）。

### Phase 2: 共通コンポーネント `lib/widgets/ll/`
- `LLPrimaryButton`/`LLSecondaryButton`/`LLIconButton`/`LLCard`/`LLTagChip`/
  `LLSegmentedControl`/`LLAppHeader`/`LLBottomSheet`(+`LLSheetTile`)/`LLDialog`/`LLFormField`。
  すべて tokens 参照・業務ロジックなし。

### Phase 3: 地図主体ホーム
- 地図部品を抽出し再利用化 `lib/widgets/map/`: `LLMapView`（CARTO/Esri 衛星切替）・
  `LLMapDetailCard`・`LLMapLegend`・`MapPin`。`MapScreen` も同部品へ置換。
- `HomeScreen` を地図主体に再構成: 地図全面＋上部ヘッダ（Info menu）＋Map/卫星切替＋
  现在位置＋「新增采集」主ボタン＋採集記録の常駐ドラッグ抽屉（`LLSignCard` 流用）。
  状態オーナー・採集/保存/导出/編集/削除の流れは不変。
- 本地保存成功 Dialog（「已保存到本地项目」）を採集完了時に表示。
- Info メニュー（关于/教程/技巧/项目设置/导出数据）→ 既存 `_openSettings`/`_export` へ委譲。

### 保留（Phase 4–6）
- CropScreen/FieldsScreen/EditSign/Settings の視覚移行、Select Location 手動微調整、
  box_selector のテーマ色化、空/エラー/ロード状態の統一は次段階。

## v1.2 (2026-06-29) — UIリデザイン（Lingscape デザインシステム）

Figma の「Lingscape」デザインを参照し、エディトリアル調に全面刷新。

### 追加
- **中央集約テーマ** `lib/theme.dart`: Lingscape のカラートークン（暖色クリーム背景・
  テラコッタ橙の主アクション・ブルー/黄/紫アクセント）、大きな角丸、ソフトな影を定義。
- **タイポグラフィ**: 見出し Fraunces（セリフ）／本文 Nunito（`google_fonts`）。
- 状態バッジ（pending/ai/modified/reviewed）の配色とチップを全画面で共通化（`statusBadge`）。
- **アプリアイコン**を Lingscape のアプリマーク（クリーム背景＋黄の書類＋橙のピン＋青い道＋紫の角丸）に刷新。
  Pillow で SVG を描画し（`assets/icon/`）、`flutter_launcher_icons` で Android/iOS/Windows に展開。

### 変更
- `main.dart` を `lingscapeTheme()` 適用に。ボタン・カード・入力・ダイアログ・FAB・
  スナックバー等が全画面で自動的に新デザインへ。
- ホーム画面: 一覧をエディトリアルなカード表示に、空状態を刷新。
- `sign_form` / `map_screen` の状態チップを共通バッジに統一。

### 依存追加
- `google_fonts` / `flutter_launcher_icons`(dev)

### 注意
- フォント（Fraunces/Nunito）は `google_fonts` の実行時取得。初回オフライン時は
  既定フォントにフォールバック（配色・形状は維持）。完全オフライン化が必要なら ttf 同梱に切替。

## v1.1 (2026-06-29) — ローカル完結化（計画C-1）＋ AI端末化

「家のPCを切ったまま外でスマホ単体で採集・閲覧・書き出し・AI判定まで完結」を実現。

### 追加
- **データ永続化**: 採集記録（疎なMap）と写真を端末に保存し、アプリ再起動後も復元（`lib/store.dart`）。
- **オフライン起動**: 後端 `/schema` に繋がらなくても端末内の既定スキーマで起動（`lib/schema_defaults.dart`）。
- **ローカル採集**: 写真の保存・クロップ・SignID採番・GPS付与を端末内で実行（`lib/imaging.dart`、後端 `/extract` 非依存）。
- **ローカル書き出し**: CSV＋写真ZIPを端末内で生成（後端 `/export_bundle` 非依存）。
- **AI端末化**: Claude / Gemini を端末から直接HTTP呼び出し（`lib/ai.dart`、後端 `/ai` 非依存）。APIキーは端末内保存。

### 変更
- 採集フロー（`crop_screen.dart` / `fields_screen.dart` / `home_screen.dart`）を後端非依存に再配線。
- 設定画面の説明を「AIキーは各社APIへ直接送信（PC不要）」に修正。

### 依存追加
- `path_provider` / `image` / `archive`

### ビルド
- リポジトリパスを ASCII 化し、その場で `flutter build apk --release` が通るようにした。
- Kotlin 増分キャッシュの close 失敗回避のため `android/gradle.properties` に
  `kotlin.incremental=false` / `org.gradle.caching=false` を追加。
- 成果物: `dist/LLMap-v1.1-release.apk`（54.6MB, universal）。

### 残課題
- EXIF読取のみ後端利用のまま（実時GPSで代替可、実用上は不要）。
- 自定义字段（スキーマのデータ化）は設計のみ・未実装。
- 実機での実通信テスト（AI応答・再起動後復元）は未実施。

## v1.0 — 初期リリース

- Phase 0〜3: FastAPI後端（EXIF/GPS・AI判定・CSV）、Flutter採集MVP、地図预览、AI填字段・承認フロー。
- 実機カメラ撮影・実時GPS、編集/削除、CSV+写真の一括エクスポート。
- 後端（PC上の uvicorn）に依存する構成。
