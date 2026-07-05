# LLMap Desktop — Tauri shell prototype（Step 10D）

`desktop/` は LLMap Desktop の最小 Tauri 2 シェルである。職責は**包装のみ**:

```text
起動 → 用户数据目录を用意 → llmap-backend sidecar を起動
→ /health ready をオーバーレイで待機 → Console(React) を表示
→ 終了時に backend 子プロセスを回収
```

Console は `console/`、backend は `backend/` の職責のまま変更しない。

## 前提（prerequisites）

- **Rust**（rustup で安定版）＋ Tauri 2 の各平台依存:
  - Linux: `libwebkit2gtk-4.1-dev libgtk-3-dev librsvg2-dev libssl-dev` ほか
    （<https://tauri.app/start/prerequisites/> 参照）
  - macOS: Xcode Command Line Tools
  - Windows: Microsoft C++ Build Tools ＋ WebView2（Win10 以降は同梱）
- Node.js（Console のビルドと `@tauri-apps/cli`）
- Python（backend binary のビルド時のみ。実行時は不要）

## 実行手順（prototype）

```bash
# 1) Console をビルド（Tauri は console/dist を読み込む）
cd console && npm run build && cd ..

# 2) backend binary を用意（当該平台でビルド。クロスビルド不可）
./scripts/build-backend-binary.sh          # → backend/dist/llmap-backend

# 3) 桌面 shell を起動
cd desktop
npm install                                # @tauri-apps/cli
npm run dev                                # = tauri dev
```

`npm run build`（= `tauri build`）は現状 bundle 無効（`bundle.active: false`）で、
実行ファイルのみ生成する。正式なインストーラは 10E–10G で扱う。

## 実装の要点

### API 地址の運行時注入

Console は接続先を次の優先順で決める（`console/src/api/client.ts`）:

```text
1. window.__LLMAP_API_BASE_URL__   ← Tauri が起動時に注入（動的端口対応）
2. VITE_API_BASE_URL               ← 従来の編譯期 env（Web dev/デプロイ用）
3. http://localhost:8000           ← 既定
```

`npm run dev` や既存のデプロイ済み console の動作は不変。

### backend sidecar の起動（prototype 方式）

prototype は `std::process::Command` で直接起動する。binary の探索順:

```text
1. 環境変数 LLMAP_BACKEND_BIN（明示指定）
2. Tauri resource dir（正式 bundle 時の置き場）
3. リポジトリ内 backend/dist/llmap-backend（開発時）
```

環境変数 `LLMAP_DATA_DIR` / `LLMAP_HOST=127.0.0.1` / `LLMAP_PORT` と
`--host/--port` 引数を渡す。端口は **8000 から空きを探索**して決める。
ログは `<data dir>/logs/backend.log` へ。

> **正式 sidecar 方案（10E で移行）**: Tauri の `externalBin`
> （`llmap-backend-$TARGET_TRIPLE` 命名で `src-tauri/binaries/` に配置）を使い、
> bundle に同梱して resource dir から起動する。permissions は
> `shell:allow-execute` 相当を capabilities で絞る。

### 用户数据目录

`app_data_dir()`（macOS: `~/Library/Application Support/app.llmap.desktop` /
Windows: `%APPDATA%\app.llmap.desktop` / Linux: `~/.local/share/app.llmap.desktop`）。
取得不能時は作業目録の `.llmap-desktop-data/` に fallback
（TODO: 正式版では fallback を廃止してエラー画面にする。また identifier 由来の
目录名を `LLMap` に揃えるかは 10E で決める）。

### 起動オーバーレイ / エラー画面

窗口は即時に開き、注入スクリプトが「Starting LLMap local backend…」の
オーバーレイを表示。/health が通った瞬間に一度だけ reload して Console を
正常状態で表示する。15 秒で ready にならない、または起動前エラー
（binary missing / data dir not writable / spawn 失敗）の場合は、原因つきの
失敗メッセージを表示する（白屏にしない）。

## 実装で判明した注意点（実測）

- **PyInstaller onefile は親子2プロセス**（bootloader 親＋server 子）で動く。
  `Child::kill()` だけでは server が残留するため、spawn 時に独立プロセスグループ
  （unix: `process_group(0)`）にし、終了時は**グループごと** SIGTERM→SIGKILL
  （Windows は `taskkill /T /F`）で回収する。窗口 CloseRequested の時点でも
  先に回収する（描画層の異常終了でも残留させないため）。
- 検証用に `LLMAP_AUTOEXIT_MS=<ms>` で正常終了を自動化できる
  （通常終了と同じ回収経路を CI/ヘッドレスで検証するための開発フック）。
- ヘッドレス Xvfb（WM 無し）では `xdotool windowclose` が Xlib エラーで
  プロセスを abort させる。実デスクトップでは発生しない環境固有の現象。

## 現在の制限（prototype）

- インストーラ・署名・自動更新なし（10E–10G）。
- sidecar は `externalBin` でなく素の `Command`（上記の正式方案に移行予定）。
- binary では `/ai` エンドポイント無効（backend-binary-build.md 参照）。
- 地図底図はオンライン tiles（離線方案は desktop-offline-design.md §7）。
- 桌面環境（GUI）が無いヘッドレス環境では `tauri dev` の窗口表示は確認できない。

## 三平台の後続計画

| 平台 | 次の Step | 主な作業 |
|---|---|---|
| macOS | 10E | externalBin 化・.app/.dmg・署名/公証 |
| Windows | 10F | 実機での backend.exe ビルド・MSI/NSIS・杀毒対策 |
| Linux | 10G | AppImage・glibc 互換ビルド |
