#!/usr/bin/env bash
# LLMap Mobile — Android 正式发布构建（Step 13）
#   ./scripts/build-mobile-android-release.sh          # 全 ABI 的 fat APK（默认，侧载分发用）
#   ./scripts/build-mobile-android-release.sh --aab    # App Bundle（上架 Google Play 用）
#   ./scripts/build-mobile-android-release.sh --split  # 按 ABI 拆分的 3 个 APK
# 不执行 flutter clean，不上传商店。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

MODE="${1:-apk}"
echo "[release-android] start: $(date '+%H:%M:%S')  mode=$MODE"
START=$(date +%s)

case "$MODE" in
  --aab)
    flutter build appbundle --release
    ARTIFACTS=(build/app/outputs/bundle/release/app-release.aab)
    ;;
  --split)
    flutter build apk --release --split-per-abi
    ARTIFACTS=(build/app/outputs/flutter-apk/app-*-release.apk)
    ;;
  apk|--apk)
    flutter build apk --release
    ARTIFACTS=(build/app/outputs/flutter-apk/app-release.apk)
    ;;
  *)
    echo "usage: $0 [--apk|--aab|--split]" >&2
    exit 2
    ;;
esac

END=$(date +%s)
echo ""
echo "[release-android] done in $((END - START))s  ($(date '+%H:%M:%S'))"
for f in "${ARTIFACTS[@]}"; do
  [[ -f "$f" ]] && echo "[release-android] artifact: app/$f ($(du -h "$f" | cut -f1 | tr -d ' '))"
done
