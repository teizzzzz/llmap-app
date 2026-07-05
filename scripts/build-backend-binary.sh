#!/usr/bin/env bash
# LLMap backend binary ビルド（macOS / Linux）。
# 生成物: backend/dist/llmap-backend
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

echo "[build] pyinstaller llmap-backend.spec"
python3 -m PyInstaller --noconfirm llmap-backend.spec

echo "[build] done:"
ls -lh dist/llmap-backend
echo "[build] 動作確認例:"
echo "  LLMAP_DATA_DIR=/tmp/llmap-test-data ./dist/llmap-backend --port 8010"
