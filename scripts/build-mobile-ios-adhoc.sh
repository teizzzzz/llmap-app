#!/usr/bin/env bash
# LLMap Mobile — iOS Ad Hoc 打包（蒲公英等分发平台用）
# 前提: 付费 Apple Developer 账号已在 Xcode 登录、目标设备 UDID 已注册到账号。
# 产物: dist/LLMap-v<version>-adhoc.ipa（注册设备可装，描述文件有效期约 1 年）。
# 不上传、不签 App Store、不执行 flutter clean。
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[adhoc-ios] unsupported: iOS build requires macOS (current: $(uname))." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

export COCOAPODS_DISABLE_STATS=true

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
OUT="$ROOT/dist/LLMap-v${VERSION}-adhoc.ipa"

echo "[adhoc-ios] start: $(date '+%H:%M:%S')  version=v${VERSION}"
START=$(date +%s)

if ! flutter build ipa --export-method ad-hoc; then
  cat >&2 <<'EOF'

[adhoc-ios] Ad Hoc 打包失败。常见原因:
  1. Apple Distribution 证书未创建 → Xcode → Settings → Accounts →
     选择账号 → Manage Certificates → + → Apple Distribution
  2. 设备 UDID 未注册 → developer.apple.com → Devices → 添加
     （蒲公英应用页可引导测试者提交 UDID）
  3. 账号未在 Xcode 登录或会话过期 → Xcode → Settings → Accounts 重新登录
EOF
  exit 1
fi

END=$(date +%s)
mkdir -p "$ROOT/dist"
IPA_SRC=$(ls build/ios/ipa/*.ipa | head -1)
cp "$IPA_SRC" "$OUT"

# 验证签名/描述文件（信息仅供人工确认，不阻断）
TMP=$(mktemp -d)
unzip -qo "$OUT" "Payload/Runner.app/embedded.mobileprovision" -d "$TMP" 2>/dev/null || true
if [[ -f "$TMP/Payload/Runner.app/embedded.mobileprovision" ]]; then
  security cms -D -i "$TMP/Payload/Runner.app/embedded.mobileprovision" > "$TMP/prof.plist" 2>/dev/null || true
  EXP=$(plutil -extract ExpirationDate raw "$TMP/prof.plist" 2>/dev/null || echo '?')
  NDEV=$(plutil -extract ProvisionedDevices raw "$TMP/prof.plist" 2>/dev/null | head -1 || echo '?')
  echo "[adhoc-ios] profile 有效期至: $EXP  注册设备数: $NDEV"
fi
rm -rf "$TMP"

echo ""
echo "[adhoc-ios] done in $((END - START))s  ($(date '+%H:%M:%S'))"
echo "[adhoc-ios] artifact: $OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"
echo "[adhoc-ios] 下一步: 上传到蒲公英 https://www.pgyer.com （拖入 ipa 即可）"
echo "[adhoc-ios] 注意: 只有 UDID 已注册到开发者账号的设备能安装。"
