#!/usr/bin/env bash
# LLMap Mobile — iOS 日常快速构建（Step 13）
# --no-codesign：不需要签名/描述文件即可完整编译验证（日常开发够用）。
# 正式打 IPA 用 build-mobile-ios-release.sh。不执行 flutter clean。
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[fast-ios] unsupported: iOS build requires macOS (current: $(uname))." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

# 本项目用 Swift Package Manager（无 Pods）；保留此设置以防未来引入 CocoaPods。
export COCOAPODS_DISABLE_STATS=true

echo "[fast-ios] start: $(date '+%H:%M:%S')"
START=$(date +%s)

flutter build ios --release --no-codesign

END=$(date +%s)
OUT="build/ios/iphoneos/Runner.app"
echo ""
echo "[fast-ios] done in $((END - START))s  ($(date '+%H:%M:%S'))"
if [[ -d "$OUT" ]]; then
  echo "[fast-ios] artifact: app/$OUT ($(du -sh "$OUT" | cut -f1 | tr -d ' '))"
else
  echo "[fast-ios] WARNING: expected artifact not found: app/$OUT" >&2
  exit 1
fi
