#!/usr/bin/env bash
# LLMap.app の Developer ID 署名 + 公証（notarization）+ dmg 作成。
#
# 前提:
#   1. desktop/ で npx tauri build --bundles app 済み（LLMap.app が存在する）
#   2. キーチェーンに "Developer ID Application" 証明書が入っている
#      （Xcode → Settings → Accounts → Manage Certificates → + で作成）
#   3. notarytool の資格情報を保存済み:
#      xcrun notarytool store-credentials llmap-notary \
#        --apple-id <Apple ID メール> --team-id <TEAM_ID> --password <app用パスワード>
#
# 使い方:
#   bash scripts/sign-and-notarize-macos.sh                 # 署名 → dmg → 公証 → staple
#   bash scripts/sign-and-notarize-macos.sh --skip-notarize # 署名 → dmg のみ
#
# 環境変数（省略可）:
#   SIGN_ID        署名 ID。省略時はキーチェーンの Developer ID Application を自動検出
#   NOTARY_PROFILE notarytool のプロファイル名（既定: llmap-notary）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$REPO_ROOT/desktop/src-tauri/target/release/bundle"
APP="$BUNDLE/macos/LLMap.app"
ENTITLEMENTS_BACKEND="$REPO_ROOT/desktop/src-tauri/entitlements/backend.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-llmap-notary}"
SKIP_NOTARIZE=0
[ "${1:-}" = "--skip-notarize" ] && SKIP_NOTARIZE=1

[ -d "$APP" ] || { echo "ERROR: $APP がありません。先に desktop/ で npx tauri build --bundles app を実行してください。" >&2; exit 1; }

# ---- 署名 ID の解決 -------------------------------------------------------
if [ -z "${SIGN_ID:-}" ]; then
  SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$SIGN_ID" ] || { echo "ERROR: Developer ID Application 証明書が見つかりません。Xcode → Settings → Accounts → Manage Certificates で作成してください。" >&2; exit 1; }
echo "[sign] identity: $SIGN_ID"

# ---- 1. sidecar 内の Mach-O を全て署名（内側から外側の順） ----------------
BACKEND_DIR="$APP/Contents/Resources/llmap-backend"
if [ -d "$BACKEND_DIR" ]; then
  echo "[sign] backend one-dir の Mach-O を署名中..."
  COUNT=0
  while IFS= read -r -d '' f; do
    if file -b "$f" | grep -q 'Mach-O'; then
      codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$f"
      COUNT=$((COUNT + 1))
    fi
  done < <(find "$BACKEND_DIR" -type f ! -name llmap-backend -print0)
  echo "[sign] backend ライブラリ ${COUNT} 個を署名"
  # 実行体本体は PyInstaller 用 entitlements 付きで署名
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS_BACKEND" --sign "$SIGN_ID" \
    "$BACKEND_DIR/llmap-backend"
  echo "[sign] backend 実行体を署名（entitlements 付き）"
fi

# ---- 2. アプリ本体を署名 --------------------------------------------------
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
echo "[sign] LLMap.app を署名"
codesign --verify --strict --deep "$APP"
echo "[sign] 検証 OK"

# ---- 3. dmg 作成 + 署名 ---------------------------------------------------
bash "$REPO_ROOT/scripts/make-macos-dmg.sh"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
ARCH="$(uname -m)"; [ "$ARCH" = "x86_64" ] && ARCH=x64
DMG="$REPO_ROOT/dist/LLMap-Desktop-v${VERSION}-macos-${ARCH}.dmg"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
echo "[sign] dmg を署名: $DMG"

if [ "$SKIP_NOTARIZE" = 1 ]; then
  echo "[done] 公証はスキップしました（--skip-notarize）"
  exit 0
fi

# ---- 4. 公証 + staple -----------------------------------------------------
echo "[notarize] Apple へ送信中（数分かかります）..."
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
# ビルド済み .app にもチケットを貼っておく（dmg 公証に含まれるので取得可能）
xcrun stapler staple "$APP" || true

# ---- 5. 最終確認 ----------------------------------------------------------
spctl -a -t open --context context:primary-signature -v "$DMG" && echo "[verify] dmg: Gatekeeper OK"
spctl -a -vv "$APP" 2>&1 | tail -2
echo "[done] 配布可能な dmg: $DMG"
