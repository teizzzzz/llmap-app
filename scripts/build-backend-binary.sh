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

# Python 3.10+ 必須 — app は `str | None` 等の PEP 604 記法を使っており、
# 3.9 でビルドすると起動時に TypeError で即死する（macOS 同梱 python3 は 3.9）。
# LLMAP_PYTHON で明示指定可（venv の python を渡す用途）。
PY="${LLMAP_PYTHON:-}"
if [ -z "$PY" ]; then
  for c in python3.13 python3.12 python3.11 python3.10 python3; do
    command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }
  done
fi
[ -n "$PY" ] || { echo "ERROR: python3 が必要です" >&2; exit 1; }
"$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' || {
  echo "ERROR: Python 3.10+ が必要です（検出: $("$PY" -V 2>&1)）。brew install python@3.11 等で導入してください。" >&2; exit 1; }
echo "[build] python: $PY ($("$PY" -V 2>&1))"

"$PY" -c "import fastapi, uvicorn, sqlmodel" 2>/dev/null || {
  echo "[build] backend 依存を導入します"; "$PY" -m pip install -r requirements.txt; }
"$PY" -c "import PyInstaller" 2>/dev/null || {
  echo "[build] PyInstaller を導入します"; "$PY" -m pip install pyinstaller; }

# one-file の残骸（ファイル）と one-dir の残骸（フォルダ）が混ざらないよう消す
rm -rf dist/llmap-backend

if [ "$(uname -s)" = "Darwin" ]; then
  echo "[build] pyinstaller llmap-backend.spec (one-dir for macOS)"
  LLMAP_PYI_ONEDIR=1 "$PY" -m PyInstaller --noconfirm llmap-backend.spec
  echo "[build] done:"
  du -sh dist/llmap-backend
  echo "[build] 動作確認例:"
  echo "  LLMAP_DATA_DIR=/tmp/llmap-test-data ./dist/llmap-backend/llmap-backend --port 8010"
else
  echo "[build] pyinstaller llmap-backend.spec (one-file)"
  "$PY" -m PyInstaller --noconfirm llmap-backend.spec
  echo "[build] done:"
  ls -lh dist/llmap-backend
  echo "[build] 動作確認例:"
  echo "  LLMAP_DATA_DIR=/tmp/llmap-test-data ./dist/llmap-backend --port 8010"
fi
