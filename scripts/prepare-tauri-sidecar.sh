#!/usr/bin/env bash
# Tauri sidecar 準備（macOS / Linux）。
# 先に ./scripts/build-backend-binary.sh で binary をビルドしておくこと。
#
# Linux : backend/dist/llmap-backend（one-file）を Tauri v2 の externalBin
#         命名規則（llmap-backend-<target triple>）で
#         desktop/src-tauri/binaries/ に配置する。
# macOS : backend/dist/llmap-backend/（one-dir）を
#         desktop/src-tauri/binaries/llmap-backend-onedir/ にコピーする。
#         tauri.macos.conf.json の bundle.resources がこれを
#         LLMap.app/Contents/Resources/llmap-backend/ として同梱する
#         （one-dir は単一ファイルでないため externalBin は使えない）。
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/desktop/src-tauri/binaries"
mkdir -p "$DEST_DIR"

if [ "$(uname -s)" = "Darwin" ]; then
  SRC="$REPO_ROOT/backend/dist/llmap-backend"
  [ -x "$SRC/llmap-backend" ] || { echo "ERROR: $SRC/llmap-backend がありません。先に scripts/build-backend-binary.sh を実行してください。" >&2; exit 1; }
  rm -rf "$DEST_DIR/llmap-backend-onedir"
  cp -R "$SRC" "$DEST_DIR/llmap-backend-onedir"
  chmod +x "$DEST_DIR/llmap-backend-onedir/llmap-backend"
  echo "[sidecar] copied: $DEST_DIR/llmap-backend-onedir/ ($(du -sh "$DEST_DIR/llmap-backend-onedir" | cut -f1))"
else
  SRC="$REPO_ROOT/backend/dist/llmap-backend"
  [ -f "$SRC" ] || { echo "ERROR: $SRC がありません。先に scripts/build-backend-binary.sh を実行してください。" >&2; exit 1; }
  TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
  [ -n "$TRIPLE" ] || { echo "ERROR: rustc が見つかりません（Rust を導入してください）。" >&2; exit 1; }
  cp "$SRC" "$DEST_DIR/llmap-backend-$TRIPLE"
  chmod +x "$DEST_DIR/llmap-backend-$TRIPLE"
  echo "[sidecar] copied: $DEST_DIR/llmap-backend-$TRIPLE"
fi
