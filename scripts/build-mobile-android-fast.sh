#!/usr/bin/env bash
# LLMap Mobile — Android 日常快速构建（Step 13）
# 只编 arm64（现代真机全部是 arm64）→ 一次 AOT 编译，比默认三 ABI 快、产物小。
# 日常真机验证用这个；发布用 build-mobile-android-release.sh。
# 不执行 flutter clean（增量构建才快，见 docs/mobile-build-optimization.md）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

echo "[fast-android] start: $(date '+%H:%M:%S')"
START=$(date +%s)

flutter build apk --release --split-per-abi --target-platform android-arm64

END=$(date +%s)
OUT="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo ""
echo "[fast-android] done in $((END - START))s  ($(date '+%H:%M:%S'))"
if [[ -f "$OUT" ]]; then
  echo "[fast-android] artifact: app/$OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"
else
  echo "[fast-android] WARNING: expected artifact not found: app/$OUT" >&2
  exit 1
fi
