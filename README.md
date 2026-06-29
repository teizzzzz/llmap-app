# LLMap App

言語景観（Linguistic Landscape）採集アプリ。LingScape / LinguaSnapp に対応する。
`mapv2.0`（桌面ツールキット）の後継として、採集〜地図表示を端末1つで完結させる。

**v1.1 より「ローカル完結（计划C）」**: 通常の採集・閲覧・AI判定・書き出しは**スマホ単体で完結**し、
PC（後端）は不要。後端は将来の多人共享（Phase 4）用に温存する。更新履歴は [CHANGELOG.md](CHANGELOG.md)。

## 採集フロー

```
拍照 → 框选景观(1图多个sign) → 读取GPS → 字段处理(端末内) → AI/手动填字段 → 保存(端末内) → 地図/导出
```

## 構成

```
llmap-app/
  app/        Flutter モバイルアプリ（採集・框选・地図预览・字段表单・AI判定・端末内保存）
  backend/    Python FastAPI 轻后端（任意。EXIF抽出と、将来の多人共享用）
```

- **単人本地**で完結。データは端末内（記録 `project.json` ＋写真）に永続化。
- AI判定は端末から Claude / Gemini API を直接呼ぶ（APIキーはアプリ設定で端末内保存）。
- CSV標準字段（`mapv2.0/PROJECT_STANDARD.md` §6/§7）を踏襲し、CSV import/export を維持。
- データ構造は将来の**多人共享**（クラウド同期）を予約。

## ロードマップ

- [x] Phase 0 — 后端化（FastAPI: `/health` `/extract` `/ai` `/export`）
- [x] Phase 1 — 採集MVP（拍照→框选→GPS→保存）
- [x] Phase 2 — 地図预览（flutter_map・言語別色分け）
- [x] Phase 3 — AI填字段（承認フロー `_status`: ai→reviewed）
- [x] **计划C-1 (v1.1)** — ローカル完結（端末内保存・オフライン起動・採集/AI/导出を後端非依存に）
- [ ] Phase 4 — 多人予約（同期API・アカウント）
- [ ] 自定义字段（スキーマのデータ化。設計のみ・未実装）

## app 起動（Windows / 開発）

```bash
cd app
flutter run -d windows
```

後端なしで起動する（v1.1〜）。AI判定を使う場合は、アプリ右上の歯車 →「AI自動識別」をオンにし、
プロバイダ（Claude / Gemini）と **APIキー**を入力（端末内に保存）。

## backend（任意 / 通常は不要）

v1.1 以降、通常運用に後端は不要。EXIF抽出の利用や、将来の多人共享の開発時のみ起動する。

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate   # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
# http://localhost:8000/docs
```

後端のAI判定（`/ai`）を使う場合のみ、環境変数で API key を渡す（CSV/コードに書かない）：

```bash
export ANTHROPIC_API_KEY=sk-...
export GEMINI_API_KEY=...
```

## Android APK ビルド

リポジトリパスを ASCII 化（`F:\Win_Workspace\LLMap\...`）したため、**その場で直接ビルドできる**。

```powershell
cd app
flutter build apk --release
#   -> build\app\outputs\flutter-apk\app-release.apk

# 成果物を dist/ に v1.x 名で回収（dist は git 管理外）
Copy-Item build\app\outputs\flutter-apk\app-release.apk ..\dist\LLMap-v1.2-release.apk -Force
```

⚠️ ビルド時の注意:
- **Kotlin 増分キャッシュの close 失敗**（`Could not close incremental caches`）が出る場合がある
  （Windows のファイルロック）。`android/gradle.properties` で `kotlin.incremental=false` /
  `org.gradle.caching=false` を設定して回避済み。再発時は `flutter clean` 後に再ビルド。
- パスに**非ASCII文字が含まれると release(AOT) が失敗する**。その場合は ASCII パスへコピーしてビルド:
  `robocopy app C:\llmap_build\app /E /XD build .dart_tool .gradle /XF *.apk`

最新ビルド: `dist/LLMap-v1.2-release.apk`（54.6MB, arm/arm64/x64 同梱の universal APK）。

## Android 実機で使う（v1.1〜：PC不要）

1. APK を端末にインストール（提供元不明アプリを許可）。
2. アプリを起動（**後端なしで起動できる**）。写真はカメラ直撮り or ギャラリー取り込み。GPSは実機で取得。
3. AI自動識別を使う場合のみ、設定で **APIキー** を入力（ネット接続が必要）。AIをオフにすれば手動入力で完結。
4. 採集データ・写真は端末内に保存され、アプリを再起動しても残る。エクスポートは CSV＋写真の ZIP を共有シートで出力。

> 後端（PC）を使う旧運用が必要な場合のみ、同一Wi-Fi上のPCで `--host 0.0.0.0` 起動し、
> アプリ「設定」の URL に `http://<PCのLAN IP>:8000`（エミュは `http://10.0.2.2:8000`）を入力する。
