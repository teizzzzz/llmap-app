#!/usr/bin/env bash
# LLMap developer launcher (macOS / Linux)
# ─────────────────────────────────────────────────────────────────────────
# これは最終製品ではない。Python + Node の入った開発環境で backend と
# Research Console を一発起動するための developer launcher である。
# 最終製品は Tauri/Electron が打包する LLMap.app / LLMap.exe / AppImage
# （docs/desktop-offline-design.md 参照）。
#
# 環境変数:
#   LLMAP_BACKEND_PORT  backend の端口（既定 8000）
#   LLMAP_CONSOLE_PORT  console dev server の端口（既定 5173）
#   LLMAP_DATA_DIR      データ保存先（既定: 三平台標準のユーザーデータ目录）
#   LLMAP_NO_BROWSER=1  ブラウザを自動で開かない（CI / headless 用）
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_PORT="${LLMAP_BACKEND_PORT:-8000}"
CONSOLE_PORT="${LLMAP_CONSOLE_PORT:-5173}"

info() { printf '\033[1;36m[llmap]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[llmap] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. 依存チェック ──────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || fail "python3 が見つかりません。https://www.python.org/ から導入してください。"
command -v node >/dev/null 2>&1 || fail "node が見つかりません。https://nodejs.org/ から導入してください。"
command -v npm >/dev/null 2>&1 || fail "npm が見つかりません。Node.js と一緒に導入されます。"

if ! python3 -c "import fastapi, uvicorn, sqlmodel" >/dev/null 2>&1; then
  info "backend の Python 依存が不足しています。導入します: pip install -r backend/requirements.txt"
  python3 -m pip install -r "$REPO_ROOT/backend/requirements.txt" || \
    fail "pip install に失敗しました。手動で 'cd backend && python3 -m pip install -r requirements.txt' を実行してください。"
fi

if [ ! -d "$REPO_ROOT/console/node_modules" ]; then
  info "console の依存が未導入です。導入します: npm install"
  (cd "$REPO_ROOT/console" && npm install) || fail "npm install に失敗しました。"
fi

# ── 2. データ目录（docs/desktop-offline-design.md §5 の標準目录） ─────────
if [ -z "${LLMAP_DATA_DIR:-}" ]; then
  case "$(uname -s)" in
    Darwin) LLMAP_DATA_DIR="$HOME/Library/Application Support/LLMap" ;;
    *)      LLMAP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/LLMap" ;;
  esac
fi
export LLMAP_DATA_DIR
mkdir -p "$LLMAP_DATA_DIR/logs" || fail "データ目录を作成できません: $LLMAP_DATA_DIR"
info "data dir: $LLMAP_DATA_DIR"

# ── 3. 端口チェック ──────────────────────────────────────────────────────
port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && exec 3>&- && return 0 || return 1; }
port_in_use "$BACKEND_PORT" && fail "端口 $BACKEND_PORT が使用中です。LLMAP_BACKEND_PORT で変更してください。"
port_in_use "$CONSOLE_PORT" && fail "端口 $CONSOLE_PORT が使用中です。LLMAP_CONSOLE_PORT で変更してください。"

# ── 4. 終了時のクリーンアップ ────────────────────────────────────────────
# npm → vite のような孫プロセスも確実に回収する（プロセス樹ごと終了）。
kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$child"; done
  kill "$pid" 2>/dev/null
}
BACKEND_PID=""
CONSOLE_PID=""
cleanup() {
  trap - INT TERM EXIT
  info "shutting down…"
  [ -n "$CONSOLE_PID" ] && kill_tree "$CONSOLE_PID"
  [ -n "$BACKEND_PID" ] && kill_tree "$BACKEND_PID"
  wait 2>/dev/null
  info "bye."
}
trap cleanup INT TERM EXIT

# ── 5. backend 起動 → /health 待機 ──────────────────────────────────────
info "starting backend on http://127.0.0.1:$BACKEND_PORT (logs: $LLMAP_DATA_DIR/logs/backend.log)"
(cd "$REPO_ROOT/backend" && exec python3 -m uvicorn app.main:app \
    --host 127.0.0.1 --port "$BACKEND_PORT") \
  >"$LLMAP_DATA_DIR/logs/backend.log" 2>&1 &
BACKEND_PID=$!

for i in $(seq 1 75); do
  if curl -sf "http://127.0.0.1:$BACKEND_PORT/health" >/dev/null 2>&1; then
    info "backend ready."
    break
  fi
  kill -0 "$BACKEND_PID" 2>/dev/null || fail "backend が起動に失敗しました。ログ: $LLMAP_DATA_DIR/logs/backend.log"
  [ "$i" -eq 75 ] && fail "backend が 15 秒以内に ready になりません。ログ: $LLMAP_DATA_DIR/logs/backend.log"
  sleep 0.2
done

# ── 6. console 起動（Vite dev server） ──────────────────────────────────
info "starting console on http://localhost:$CONSOLE_PORT (logs: $LLMAP_DATA_DIR/logs/console.log)"
(cd "$REPO_ROOT/console" && \
  VITE_API_BASE_URL="http://127.0.0.1:$BACKEND_PORT" \
  exec npm run dev -- --port "$CONSOLE_PORT" --strictPort) \
  >"$LLMAP_DATA_DIR/logs/console.log" 2>&1 &
CONSOLE_PID=$!

for i in $(seq 1 100); do
  if curl -sf "http://localhost:$CONSOLE_PORT/" >/dev/null 2>&1; then
    info "console ready."
    break
  fi
  kill -0 "$CONSOLE_PID" 2>/dev/null || fail "console が起動に失敗しました。ログ: $LLMAP_DATA_DIR/logs/console.log"
  [ "$i" -eq 100 ] && fail "console が 20 秒以内に ready になりません。ログ: $LLMAP_DATA_DIR/logs/console.log"
  sleep 0.2
done

# ── 7. ブラウザを開く ───────────────────────────────────────────────────
URL="http://localhost:$CONSOLE_PORT"
if [ "${LLMAP_NO_BROWSER:-0}" != "1" ]; then
  if command -v open >/dev/null 2>&1; then open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || true
  else info "ブラウザで開いてください: $URL"
  fi
fi

info "LLMap is running:"
info "  console : $URL"
info "  backend : http://127.0.0.1:$BACKEND_PORT (docs: /docs)"
info "Ctrl+C で終了します（backend / console を両方停止します）。"
wait
