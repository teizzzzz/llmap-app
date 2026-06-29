# 更新履歴 (CHANGELOG)

バージョン採番は v1.0 / v1.1 / v1.2 ... と進める。
APK 成果物のファイル名もこれに合わせる（例 `dist/LLMap-v1.1-release.apk`）。

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
