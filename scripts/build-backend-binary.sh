#!/usr/bin/env bash
# LLMap backend binary ビルド（macOS / Linux）。
# 生成物:
#   Linux : backend/dist/llmap-backend            （one-file）
#   macOS : backend/dist/llmap-backend/           （one-dir: 実行体 + _internal/）
# macOS が one-dir なのは、one-file だと起動のたびに展開された dylib 群へ
# macOS のコード署名検証が走り /health ready まで毎回 15〜25 秒かかるため
# （Step 10E 実測。one-dir は 2 回目以降 ~1 秒）。
# 注意: PyInstaller はクロスビルド不可 — macOS 用は macOS で、Linux 用は
#       Linux でビルドすること（docs/backend-binary-build.md 参照）。
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/backend"

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です" >&2; exit 1; }

python3 -c "import fastapi, uvicorn, sqlmodel" 2>/dev/null || {
  echo "[build] backend 依存を導入します"; python3 -m pip install -r requirements.txt; }
python3 -c "import PyInstaller" 2>/dev/null || {
  echo "[build] PyInstaller を導入します"; python3 -m pip install pyinstaller; }

# one-file の残骸（ファイル）と one-dir の残骸（フォルダ）が混ざらないよう消す
rm -rf dist/llmap-backend

if [ "$(uname -s)" = "Darwin" ]; then
  echo "[build] pyinstaller llmap-backend.spec (one-dir for macOS)"
  LLMAP_PYI_ONEDIR=1 python3 -m PyInstaller --noconfirm llmap-backend.spec
  echo "[build] done:"
  du -sh dist/llmap-backend
  echo "[build] 動作確認例:"
  echo "  LLMAP_DATA_DIR=/tmp/llmap-test-data ./dist/llmap-backend/llmap-backend --port 8010"
else
  echo "[build] pyinstaller llmap-backend.spec (one-file)"
  python3 -m PyInstaller --noconfirm llmap-backend.spec
  echo "[build] done:"
  ls -lh dist/llmap-backend
  echo "[build] 動作確認例:"
  echo "  LLMAP_DATA_DIR=/tmp/llmap-test-data ./dist/llmap-backend --port 8010"
fi
