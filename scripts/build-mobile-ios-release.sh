#!/usr/bin/env bash
# LLMap Mobile — iOS 正式发布构建（Step 13）
# 产出 IPA（需要 Xcode 里配置好 Team / 签名）。不上传 App Store。
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[release-ios] unsupported: iOS build requires macOS (current: $(uname))." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

export COCOAPODS_DISABLE_STATS=true

echo "[release-ios] start: $(date '+%H:%M:%S')"
START=$(date +%s)

if ! flutter build ipa --release; then
  cat >&2 <<'EOF'

[release-ios] IPA 构建失败。常见原因是签名未配置：
  1. 打开 app/ios/Runner.xcworkspace
  2. Runner → Signing & Capabilities → 选择 Team，开启 Automatically manage signing
  3. 重新运行本脚本
仅想验证编译是否通过（无需签名）请改用: ./scripts/build-mobile-ios-fast.sh
EOF
  exit 1
fi

END=$(date +%s)
echo ""
echo "[release-ios] done in $((END - START))s  ($(date '+%H:%M:%S'))"
IPA_DIR="build/ios/ipa"
if compgen -G "$IPA_DIR/*.ipa" > /dev/null; then
  for f in "$IPA_DIR"/*.ipa; do
    echo "[release-ios] artifact: app/$f ($(du -h "$f" | cut -f1 | tr -d ' '))"
  done
else
  echo "[release-ios] note: xcarchive at app/build/ios/archive/ (IPA export may need distribution settings)"
fi
