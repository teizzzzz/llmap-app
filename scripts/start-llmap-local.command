#!/usr/bin/env bash
# LLMap developer launcher — macOS 双击入口。
# 実体は start-llmap-local.sh（これを Terminal で開いて実行するだけ）。
#
# 初回は実行権限が必要です:
#   chmod +x scripts/start-llmap-local.command scripts/start-llmap-local.sh
# Gatekeeper に止められた場合は 右クリック → 開く を選んでください。
cd "$(dirname "$0")" || exit 1
exec ./start-llmap-local.sh
