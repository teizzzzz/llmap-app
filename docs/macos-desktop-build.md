# LLMap Desktop — macOS ビルドガイド（Step 10E）

macOS 上で LLMap Desktop（Tauri shell + llmap-backend sidecar）をビルドし、
`LLMap.app` / `.dmg` を生成する手順。**macOS の App は macOS でしか
ビルドできない**（PyInstaller・Tauri ともクロスコンパイル不可）。
本ガイドの内容は **Apple Silicon (arm64)・macOS 26.5 実機で検証済み**（§10）。

## 1. Prerequisites（macOS 12+ / Apple Silicon）

| 要件 | 用途 | 導入 |
|---|---|---|
| Xcode Command Line Tools | Rust のリンク・iconutil 等 | `xcode-select --install` |
| Python 3.11+ | backend のビルド（**利用者には不要**） | `brew install python@3.11` |
| Node.js 18+ | Console ビルド・@tauri-apps/cli | nodejs.org / brew |
| Rust（stable） | Tauri shell | `curl https://sh.rustup.rs \| sh` |

- Homebrew の Python は PEP 668（externally managed）のため pip を直接使えない。
  **venv を作ってから**ビルドスクリプトを実行する:

  ```bash
  cd backend
  /opt/homebrew/opt/python@3.11/bin/python3.11 -m venv .venv
  source .venv/bin/activate      # 以後 python3 = venv の 3.11
  ```

- Intel Mac 向け binary は Intel 実機（または universal2 ビルド、将来課題）が
  必要。本ガイドの生成物は **arm64 専用**（dmg 名: `LLMap_<ver>_aarch64.dmg`）。

## 2. backend binary のビルド（macOS は one-dir）

```bash
cd backend && python -m pytest tests/ -q     # まず既存テスト（17件）
cd .. && ./scripts/build-backend-binary.sh
# → backend/dist/llmap-backend/            ← フォルダ（one-dir）
#      llmap-backend                        実行体
#      _internal/                           Python runtime + 依存
```

**macOS だけ one-dir なのは実測による**（Linux/Windows は one-file のまま）:

| 形態 | /health ready まで（M4 Pro 実測） |
|---|---|
| one-file | **毎回 15〜25 秒**（起動毎に dylib 群を展開 → その都度 macOS がコード署名検証） |
| one-dir 初回 | 約 25 秒（初回のみの検証。結果は cdhash 単位でキャッシュされる） |
| one-dir 2回目以降 | **約 0.6 秒** |

スクリプトは `uname` で自動判別する（`LLMAP_PYI_ONEDIR=1` が macOS で有効になる。
spec は共通の `backend/llmap-backend.spec`）。

単体動作確認:

```bash
LLMAP_DATA_DIR=/tmp/llmap-test ./backend/dist/llmap-backend/llmap-backend --port 8010
curl http://127.0.0.1:8010/health   # → {"ok":true,...}
```

## 3. sidecar の配置（externalBin ではなく resources）

one-dir は単一ファイルでないため Tauri の `externalBin` は使えない。
`tauri.macos.conf.json`（macOS でのみ自動マージ）の `bundle.resources` で
フォルダごと同梱する:

```bash
./scripts/prepare-tauri-sidecar.sh
# → desktop/src-tauri/binaries/llmap-backend-onedir/   （46MB 程度）
#   ↓ tauri build 時に
# LLMap.app/Contents/Resources/llmap-backend/llmap-backend として同梱される
```

shell 側の実行時探索順（main.rs）: `LLMAP_BACKEND_BIN` → App 実行ファイルと
同じ目录 → **resource dir**（各目录で 素の名前 / `-<triple>` 付き /
`llmap-backend/llmap-backend` one-dir 形の3つを試す）→ repo の `backend/dist`。
インストール後は resource dir の one-dir 形で見つかる。

## 4. Desktop のビルドと実行

```bash
cd console && npm run build && cd ..       # Console assets（tauri build に必須）
cd desktop
npm install
npm run dev                                 # 開発実行（窗口が開く）
npx tauri build --bundles app               # → LLMap.app
# → desktop/src-tauri/target/release/bundle/macos/LLMap.app （約 68MB）
```

`tauri.macos.conf.json`（macOS でのみ自動マージされる平台設定）:

- `targets: ["app", "dmg"]`・`icon: icons/icon.icns`（icon-1024.png から生成）
- `resources: {"binaries/llmap-backend-onedir": "llmap-backend"}`（§3）

## 5. DMG の生成

**ヘッドレス環境（CI・エージェント実行）では Tauri 標準の dmg バンドラは
使えない**（内部の bundle_dmg.sh が Finder への AppleScript 自動化権限を
要求するため）。hdiutil だけで作る同梱スクリプトを使う:

```bash
./scripts/make-macos-dmg.sh
# → desktop/src-tauri/target/release/bundle/dmg/LLMap_0.1.0_aarch64.dmg （約 35MB）
#   内容: LLMap.app + /Applications シンボリックリンク（drag & drop 導入）
```

対話ターミナルからなら `npx tauri build --bundles dmg` も使える
（初回に「Finder を制御するアクセス許可」を求められる → 許可）。

## 6. 未署名 App の実行 / Gatekeeper

- 本 prototype は**未署名**（linker による ad-hoc 署名のみ。Apple Silicon では
  全実行ファイルに最低限 ad-hoc 署名が必須で、Tauri/PyInstaller が自動処理）。
- **本機でビルドした App はそのまま起動できる**（quarantine が付かないため）。
- **dmg を配布して別の Mac に導入した場合**は quarantine が付き、初回起動で
  「開発元を検証できません」と警告される。回避:
  右クリック →「開く」→「開く」、または
  `xattr -dr com.apple.quarantine /Applications/LLMap.app`
- 初回起動は macOS が同梱ファイル群を検証するため backend ready まで
  **数十秒かかることがある**（2回目以降は約1秒。起動オーバーレイは
  60 秒まで待ち、10 秒経過で案内文言を出す）。
- 根本対策は **Developer ID 署名 + 公証（notarization）**（正式配布時に対応。
  Apple Developer Program 加入が必要）。

## 7. データ目录

```text
~/Library/Application Support/LLMap/
  llmap.sqlite3  photos/  source_photos/  imports/  exports/  logs/
```

- shell が `LLMAP_DATA_DIR=~/Library/Application Support/LLMap` を設定して
  sidecar を起動する（OS data dir + `LLMap`。developer launcher と同一パスなので
  launcher で作ったデータをそのまま開ける）。
- App bundle 内にはユーザーデータを置かない。
  **App を升級・再導入してもデータは保持される**（§10 で実測）。

## 8. 終了時のプロセス回収

- shell は sidecar を独立プロセスグループで起動し、終了時（窗口 close /
  ExitRequested / Exit）に**グループごと SIGTERM → SIGKILL** で回収する。
- one-dir の backend は単一プロセスだが、Linux（one-file: bootloader 親＋
  server 子の2プロセス）と共通の回収コードで動く。
- 確認: App 終了後に `pgrep -x llmap-backend` が空であること。

## 9. Troubleshooting

| 症状 | 対処 |
|---|---|
| 端口 in use | shell は 8000〜8019 を自動探索する（8000 占用時に 8001 へ移ることを実測済み） |
| backend missing 表示 | `scripts/build-backend-binary.sh` → `scripts/prepare-tauri-sidecar.sh` の順で再実行。開発時は `LLMAP_BACKEND_BIN=/path/to/llmap-backend` で直接指定可 |
| 初回起動が遅い（〜60秒） | §6 の初回検証。2回目以降は約1秒になる。`<data dir>/logs/backend.log` も確認 |
| 「開発元を検証できません」 | §6 の右クリック→開く / xattr |
| pip install が拒否される | PEP 668。§1 の venv を使う |
| dmg 生成が失敗する（ヘッドレス） | Tauri 標準バンドラ不可。`scripts/make-macos-dmg.sh` を使う（§5） |
| 終了後にプロセス残留 | 異常終了時のみ起こり得る。`pkill -x llmap-backend` で回収し、logs/backend.log を確認 |

## 10. macOS 実機チェックリスト（2026-07-06 実施 — M4 Pro / macOS 26.5 / arm64）

- [x] `python -m pytest tests/ -q`（17件 passed・Python 3.11.15）
- [x] backend one-dir ビルド → 単体で `/health` `/schema` OK・SQLite 生成・
      SIGTERM で残留なし（ready まで初回 25s / 以後 0.6s）
- [x] sidecar 準備 → `npx tauri build --bundles app` → `LLMap.app` 生成（68MB）
- [x] App 起動（直接実行・`open` = 双击相当の両方）→ backend 自動起動 →
      `/health` 200（初回 1.9s / 以後 0.8s）※ dist 検証済み dylib のため初回も高速
- [x] Import / Database（写真配信）/ Map / Review（PATCH）/ Export CSV / Stats
      を実 App の backend に対して E2E 検証（9項目 PASS）
- [x] `~/Library/Application Support/LLMap` にデータ生成・App 再起動後も保持
      （導入データ・review 状態が次回起動の実例で確認できた）
- [x] 終了（LLMAP_AUTOEXIT_MS 経由の正常終了経路）後 `pgrep -x llmap-backend` が空
- [x] 端口 8000 占用時に自動で 8001 → `/health` OK
- [x] sidecar を退避して起動 → エラー表示経路（クラッシュ・白屏なし、exit 0）
- [x] `scripts/make-macos-dmg.sh` で dmg 生成 → マウント → App +
      Applications リンク・実行権限・署名を確認 → デタッチ
- [ ] 別の Mac（quarantine あり）での右クリック→開く手順・Intel/universal2 ビルド
      （未実施 — 実機なし）
