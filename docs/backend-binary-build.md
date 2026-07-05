# LLMap backend binary — ビルドと運用（Step 10C）

FastAPI backend を **PyInstaller** で単体実行ファイル化する手順。
生成物があれば、ユーザーは Python / pip / uvicorn を導入せずに backend を
起動できる（将来の Tauri 桌面 shell はこの binary を子プロセスとして起動する）。

```text
backend/dist/llmap-backend        # Linux（one-file）
backend/dist/llmap-backend/       # macOS（one-dir: llmap-backend + _internal/）
backend/dist/llmap-backend.exe    # Windows（one-file）
```

macOS だけ one-dir なのは、one-file だと起動のたびに展開される dylib 群へ
macOS のコード署名検証が走り /health ready まで**毎回 15〜25 秒**かかるため
（Step 10E 実測。one-dir は 2 回目以降 ~0.6 秒。詳細は
docs/macos-desktop-build.md §2）。`scripts/build-backend-binary.sh` が
`uname` で自動判別する（spec の `LLMAP_PYI_ONEDIR=1` スイッチ）。

## 重要な前提: クロスビルド不可

PyInstaller は原則としてクロスコンパイルできない。

- **Windows 用 exe は Windows で**、**macOS 用は macOS で**、
  **Linux 用は Linux で**ビルドすること。
- さらに macOS は arm64 / x86_64 でも分かれる（古い Intel Mac 向けには
  Intel 環境か universal2 ビルドが必要）。
- Linux binary は「ビルドした環境より古い glibc」では動かないため、
  配布向けには古めのディストリ（または manylinux コンテナ）でビルドする。

## ビルド手順

### macOS / Linux

```bash
./scripts/build-backend-binary.sh
# 実体は以下と同じ:
#   cd backend
#   pip install -r requirements.txt
#   pip install pyinstaller
#   pyinstaller llmap-backend.spec
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-backend-binary.ps1
# 実体:
#   cd backend
#   pip install -r requirements.txt
#   pip install pyinstaller
#   pyinstaller llmap-backend.spec
```

## 実行方法

```bash
LLMAP_DATA_DIR=/tmp/llmap-test-data ./backend/dist/llmap-backend --port 8010
# または CLI 引数で
./backend/dist/llmap-backend --host 127.0.0.1 --port 8010 --data-dir /path/to/data
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/schema
```

- 既定は **127.0.0.1:8000**（`0.0.0.0` は既定にしない。本 backend は認証を
  持たないため、非 localhost での待受には起動時に警告を出す）。
- `LLMAP_HOST` / `LLMAP_PORT` / `LLMAP_DATA_DIR` の環境変数、
  または `--host/--port/--data-dir` の CLI 引数で調整（CLI が優先）。
- 開発時は従来どおり `uvicorn app.main:app --reload` を使う
  （`run_backend.py` はそれに影響しない）。

## spec の設計判断（backend/llmap-backend.spec）

- **one-file を採用**: Tauri sidecar として「単一パスの実行ファイル」を
  扱えることを最優先（one-folder は起動が僅かに速いが、数百ファイルの
  ディレクトリを bundle 管理する必要がある）。
- **hidden imports**: uvicorn（実行時に文字列でモジュール解決するため
  `collect_submodules`）、python-multipart（/datasets/import の multipart）、
  Pillow の JPEG プラグイン、pydantic_core。
- **除外**: anthropic / google-genai（app/ai.py が関数内で遅延 import して
  いるため除外可能。**binary では /ai エンドポイントは使えない**——呼ぶと
  ImportError 由来の 502 になる。桌面 MVP は /ai を使わない）、
  tkinter / pytest / numpy 等の不要物、`backend/data/`・テスト・仮想環境。
- **UPX 不使用**: Windows の杀毒误报を悪化させるため。

## 計測

Linux x86_64・Python 3.11（one-file）:

| 項目 | 実測値 |
|---|---|
| binary 体積 | 約 30 MB（one-file・AI SDK 除外時） |
| 起動 → /health ready | 約 1.5 秒（one-file の自己展開込み） |
| multipart 導入 / SQLite / 写真書込 / CSV導出 | すべて通常起動と同一動作を確認 |

macOS arm64 (M4 Pro)・Python 3.11（Step 10E 実測）:

| 項目 | 実測値 |
|---|---|
| one-file 起動 → ready | **毎回 15〜25 秒**（起動毎の署名検証。採用せず） |
| one-dir 体積 / 起動 → ready | 約 46 MB / 初回 約25秒・**以後 約0.6秒**（採用） |

## 既知の注意点

- **Windows 杀毒误报**: PyInstaller onefile は誤検知されやすい。UPX 不使用で
  低減しているが、配布時はコード署名（10F）と Defender への申告が最終対策。
- **macOS Gatekeeper**: 本機ビルドはそのまま起動できるが、**配布**（quarantine
  付き）では初回起動がブロックされる。回避手順と初回検証の遅延は
  docs/macos-desktop-build.md §6 参照。Developer ID 署名・公証は正式配布時に対応。
- **一時展開ディレクトリ**: one-file は起動時に一時領域へ自己展開する。
  異常終了で一時ファイルが残ることがある（OS が定期清掃する）。
- **/ai エンドポイント**: 上記のとおり binary では無効（開発用 uvicorn 起動では
  従来どおり利用可能）。
