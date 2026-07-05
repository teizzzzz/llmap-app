# LLMap Desktop — Windows ビルドガイド（Step 10F）

Windows 上で LLMap Desktop（Tauri shell + llmap-backend.exe sidecar）を
ビルド・実行する手順。**Windows の exe / インストーラは Windows 実機でしか
ビルドできない**（PyInstaller・Tauri ともクロスコンパイル不可）。

## 1. Prerequisites（Windows 10/11）

| 要件 | 用途 | 導入 |
|---|---|---|
| Python 3.11+ | backend exe のビルド（**利用者には不要**） | python.org |
| Node.js 18+ | Console ビルド・@tauri-apps/cli | nodejs.org |
| Rust（stable） | Tauri shell | rustup.rs（MSVC toolchain） |
| Microsoft C++ Build Tools | Rust の MSVC リンク | Visual Studio Installer |
| WebView2 Runtime | Tauri の描画（§5） | Win10/11 は通常同梱 |

## 2. backend exe のビルド

```powershell
cd backend
python -m pytest tests\ -q          # まず既存テスト
cd ..
powershell -ExecutionPolicy Bypass -File scripts\build-backend-binary.ps1
# → backend\dist\llmap-backend.exe
```

単体動作確認:

```powershell
$env:LLMAP_DATA_DIR="$env:APPDATA\LLMap-Test"
.\backend\dist\llmap-backend.exe --port 8010
# 別ターミナルで:
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/schema
```

`--host/--port/--data-dir` と `LLMAP_HOST/LLMAP_PORT/LLMAP_DATA_DIR` に対応。
既定は 127.0.0.1:8000。`backend\data\` は同梱されない。

## 3. sidecar の配置（Tauri v2 externalBin 規則）

Tauri v2 の externalBin は **`<名前>-<target triple>[.exe]`** という実体名を要求する。
`tauri.windows.conf.json` に `"externalBin": ["binaries/llmap-backend"]` を設定済み
なので、実体を次の名前で置く（スクリプトが自動処理）:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\prepare-tauri-sidecar.ps1
# → desktop\src-tauri\binaries\llmap-backend-x86_64-pc-windows-msvc.exe
#   （triple は rustc -vV の host から自動取得）
```

shell 側の実行時探索順: `LLMAP_BACKEND_BIN`（開発 fallback）→ **App exe と同じ
目录**（素の名前 / triple 付き名の両方）→ resource dir → repo の `backend\dist`。
インストール後は NSIS が sidecar を `LLMap.exe` の隣に配置するため②で見つかる。

## 4. Desktop のビルドと実行

```powershell
cd console; npm run build; cd ..          # Console assets
cd desktop
npm install
npm run dev                                # 開発実行（窗口が開く）
npm run build                              # = tauri build → NSIS インストーラ
# → desktop\src-tauri\target\release\bundle\nsis\LLMap_0.1.0_x64-setup.exe
```

`tauri.windows.conf.json`（Windows でのみ自動マージされる平台設定）:

- `targets: ["nsis"]`・`installMode: currentUser`（管理者権限不要で導入）
- `icon: icons/icon.ico`（暫定 terracotta map pin。多サイズ同梱）
- `webviewInstallMode: downloadBootstrapper`（WebView2 不在時に導入を案内）

## 5. WebView2

- Windows 10/11 には通常 **WebView2 Runtime が同梱**されており追加導入不要。
- 無い環境では NSIS インストーラが bootstrapper 経由で導入を案内する
  （`downloadBootstrapper` 設定済み。オフライン埋め込みは将来検討）。
- `tauri dev` で窗口が開かない場合はまず WebView2 Runtime の有無を確認する。

## 6. 未署名 App の実行 / Defender / SmartScreen

- 本 prototype は**未署名**。初回起動時に **SmartScreen** が警告する →
  「詳細情報」→「実行」で起動できる。
- **Windows Defender / 杀毒误报**: PyInstaller onefile exe は誤検知されやすい。
  低減策として UPX を使っていないが、それでも隔離されることがある。
  - 隔離された場合: Defender の「保護の履歴」から復元し、
    `backend\dist` / インストール先を除外に追加する。
  - 根本対策は**コード署名証明書での署名**（正式配布時に対応）。
- 配布時は zip 経由の「Mark of the Web」にも注意（プロパティ→ブロック解除）。

## 7. データ目录

```text
%APPDATA%\LLMap\
  llmap.sqlite3  photos\  source_photos\  imports\  exports\  logs\  config.json
```

- shell が `LLMAP_DATA_DIR=%APPDATA%\LLMap` を設定して sidecar を起動する
  （OS の Roaming AppData + `LLMap`。developer launcher と同一パスなので
  launcher で作ったデータをそのまま開ける）。
- インストール先（Program Files 等）にはユーザーデータを置かない。
  **App を升級・再インストールしてもデータは保持される。**

## 8. 終了時のプロセス回収

- shell は sidecar を独立プロセスとして起動し、終了時（窗口 close /
  ExitRequested / Exit）に **`taskkill /T /F /PID <pid>`** でプロセスツリーごと
  回収する（PyInstaller onefile は親子2プロセスのため /T が必須）。
- 確認: App 終了後に `Get-Process llmap-backend -ErrorAction SilentlyContinue`
  が空であること。

## 9. Troubleshooting

| 症状 | 対処 |
|---|---|
| 端口 in use | shell は 8000〜8019 を自動探索する。全滅なら他プロセスを止めるか `LLMAP_BACKEND_BIN`＋手動起動で切り分け |
| backend missing 表示 | `scripts\build-backend-binary.ps1` → `scripts\prepare-tauri-sidecar.ps1` の順で再実行。開発時は `$env:LLMAP_BACKEND_BIN` で直接指定可 |
| WebView2 missing | Evergreen WebView2 Runtime を導入（§5） |
| Defender 隔離 | §6 の手順で復元・除外。頻発するなら SmartScreen 情報も確認 |
| 終了後にプロセス残留 | 異常終了時のみ起こり得る。`taskkill /F /T /IM llmap-backend.exe` で回収し、`%APPDATA%\LLMap\logs\backend.log` を確認 |
| 起動 15 秒超過エラー | `%APPDATA%\LLMap\logs\backend.log` を確認（初回は onefile 自己展開で数秒かかる） |

## 10. Windows 実機チェックリスト（未実施 — 本環境は Linux）

- [ ] `python -m pytest tests\ -q`（17件）
- [ ] backend exe ビルド → `/health` `/schema` `/datasets/import` `/records` 写真配信 CSV export
- [ ] sidecar 準備 → `npm run dev` で窗口起動 → 顶栏 backend online
- [ ] Import / Database（写真表示）/ Map / Review / Export CSV
- [ ] `%APPDATA%\LLMap` にデータ生成・App 再起動後も保持
- [ ] 終了後 `Get-Process llmap-backend` が空
- [ ] 端口 8000 占用時に自動で 8001 へ
- [ ] backend exe を退避して起動 → エラー表示（白屏なし）
- [ ] `npm run build` で NSIS インストーラ生成 → 導入 → 双击起動
- [ ] SmartScreen 警告の回避手順確認
