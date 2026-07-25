#!/usr/bin/env bash
# LLMap.app から .dmg を作る（macOS。hdiutil のみ使用）。
#
# Tauri 標準の dmg バンドラ（bundle_dmg.sh）は Finder への AppleScript
# 自動化権限を要求するため、ヘッドレス環境（CI・エージェント実行）では
# 失敗する。本スクリプトは hdiutil だけで同等物（App + /Applications
# シンボリックリンク入りの圧縮 dmg）を作る。
#
# 前提: npx tauri build --bundles app 済み（desktop/ で）。
# 生成物: desktop/src-tauri/target/release/bundle/dmg/LLMap_<version>_aarch64.dmg
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$REPO_ROOT/desktop/src-tauri/target/release/bundle"
APP="$BUNDLE/macos/LLMap.app"
[ -d "$APP" ] || { echo "ERROR: $APP がありません。先に desktop/ で npx tauri build --bundles app を実行してください。" >&2; exit 1; }

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
ARCH="$(uname -m)"; [ "$ARCH" = "arm64" ] && ARCH=aarch64
OUT_DIR="$BUNDLE/dmg"
OUT="$OUT_DIR/LLMap_${VERSION}_${ARCH}.dmg"
mkdir -p "$OUT_DIR"

STAGING="$(mktemp -d /tmp/llmap-dmg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "LLMap" -srcfolder "$STAGING" -ov -format UDZO "$OUT" >/dev/null
echo "[dmg] created: $OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"
