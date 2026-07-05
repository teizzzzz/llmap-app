#!/usr/bin/env bash
# Tauri sidecar 準備（macOS / Linux）。
# backend/dist/llmap-backend を Tauri v2 の externalBin 命名規則
# （llmap-backend-<target triple>）で desktop/src-tauri/binaries/ に配置する。
# 先に ./scripts/build-backend-binary.sh で binary をビルドしておくこと。
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/backend/dist/llmap-backend"
[ -f "$SRC" ] || { echo "ERROR: $SRC がありません。先に scripts/build-backend-binary.sh を実行してください。" >&2; exit 1; }

TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
[ -n "$TRIPLE" ] || { echo "ERROR: rustc が見つかりません（Rust を導入してください）。" >&2; exit 1; }

DEST_DIR="$REPO_ROOT/desktop/src-tauri/binaries"
mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/llmap-backend-$TRIPLE"
chmod +x "$DEST_DIR/llmap-backend-$TRIPLE"
echo "[sidecar] copied: $DEST_DIR/llmap-backend-$TRIPLE"
