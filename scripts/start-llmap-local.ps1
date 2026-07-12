# LLMap developer launcher (Windows / PowerShell)
# ─────────────────────────────────────────────────────────────────────────
# これは最終製品ではない。Python + Node の入った開発環境で backend と
# Research Console を一発起動するための developer launcher である。
# 最終製品は Tauri/Electron が打包する LLMap.exe（docs/desktop-offline-design.md）。
#
# 実行: powershell -ExecutionPolicy Bypass -File scripts\start-llmap-local.ps1
# （双击起動は start-llmap-local.bat を使う）
#
# 環境変数: LLMAP_BACKEND_PORT / LLMAP_CONSOLE_PORT / LLMAP_DATA_DIR / LLMAP_NO_BROWSER
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BackendPort = if ($env:LLMAP_BACKEND_PORT) { $env:LLMAP_BACKEND_PORT } else { '8000' }
$ConsolePort = if ($env:LLMAP_CONSOLE_PORT) { $env:LLMAP_CONSOLE_PORT } else { '5173' }

function Info($msg) { Write-Host "[llmap] $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "[llmap] ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── 1. 依存チェック ──
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { Fail 'python が見つかりません。https://www.python.org/ から導入してください。' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'node が見つかりません。https://nodejs.org/ から導入してください。' }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Fail 'npm が見つかりません。Node.js と一緒に導入されます。' }

& $python.Source -c 'import fastapi, uvicorn, sqlmodel' 2>$null
if ($LASTEXITCODE -ne 0) {
    Info 'backend の Python 依存が不足しています。導入します: pip install -r backend\requirements.txt'
    & $python.Source -m pip install -r (Join-Path $RepoRoot 'backend\requirements.txt')
    if ($LASTEXITCODE -ne 0) { Fail 'pip install に失敗しました。' }
}
if (-not (Test-Path (Join-Path $RepoRoot 'console\node_modules'))) {
    Info 'console の依存が未導入です。導入します: npm install'
    Push-Location (Join-Path $RepoRoot 'console'); npm install; Pop-Location
    if ($LASTEXITCODE -ne 0) { Fail 'npm install に失敗しました。' }
}

# ── 2. データ目录（%APPDATA%\LLMap） ──
$DataDir = if ($env:LLMAP_DATA_DIR) { $env:LLMAP_DATA_DIR } else { Join-Path $env:APPDATA 'LLMap' }
$env:LLMAP_DATA_DIR = $DataDir
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir 'logs') | Out-Null
Info "data dir: $DataDir"

# ── 3. 端口チェック ──
foreach ($p in @($BackendPort, $ConsolePort)) {
    $inUse = Test-NetConnection -ComputerName 127.0.0.1 -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($inUse) { Fail "端口 $p が使用中です。LLMAP_BACKEND_PORT / LLMAP_CONSOLE_PORT で変更してください。" }
}

# ── 4-6. backend / console 起動 → health 待機 ──
$backendLog = Join-Path $DataDir 'logs\backend.log'
$consoleLog = Join-Path $DataDir 'logs\console.log'
$backend = $null; $console = $null
try {
    Info "starting backend on http://127.0.0.1:$BackendPort (logs: $backendLog)"
    $backend = Start-Process -FilePath $python.Source `
        -ArgumentList @('-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', $BackendPort) `
        -WorkingDirectory (Join-Path $RepoRoot 'backend') `
        -RedirectStandardOutput $backendLog -RedirectStandardError "$backendLog.err" `
        -NoNewWindow -PassThru

    $ready = $false
    foreach ($i in 1..75) {
        try {
            Invoke-WebRequest "http://127.0.0.1:$BackendPort/health" -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true; break
        } catch { Start-Sleep -Milliseconds 200 }
        if ($backend.HasExited) { Fail "backend が起動に失敗しました。ログ: $backendLog" }
    }
    if (-not $ready) { Fail "backend が 15 秒以内に ready になりません。ログ: $backendLog" }
    Info 'backend ready.'

    Info "starting console on http://localhost:$ConsolePort (logs: $consoleLog)"
    $env:VITE_API_BASE_URL = "http://127.0.0.1:$BackendPort"
    $console = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList @('/c', "npm run dev -- --port $ConsolePort --strictPort") `
        -WorkingDirectory (Join-Path $RepoRoot 'console') `
        -RedirectStandardOutput $consoleLog -RedirectStandardError "$consoleLog.err" `
        -NoNewWindow -PassThru

    $ready = $false
    foreach ($i in 1..100) {
        try {
            Invoke-WebRequest "http://localhost:$ConsolePort/" -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true; break
        } catch { Start-Sleep -Milliseconds 200 }
        if ($console.HasExited) { Fail "console が起動に失敗しました。ログ: $consoleLog" }
    }
    if (-not $ready) { Fail "console が 20 秒以内に ready になりません。ログ: $consoleLog" }
    Info 'console ready.'

    # ── 7. ブラウザ ──
    if ($env:LLMAP_NO_BROWSER -ne '1') { Start-Process "http://localhost:$ConsolePort" }

    Info 'LLMap is running:'
    Info "  console : http://localhost:$ConsolePort"
    Info "  backend : http://127.0.0.1:$BackendPort (docs: /docs)"
    Info 'このウィンドウで Ctrl+C（または閉じる）で終了します。'
    Wait-Process -Id $console.Id
}
finally {
    Info 'shutting down…'
    foreach ($proc in @($console, $backend)) {
        if ($proc -and -not $proc.HasExited) {
            # npm 経由の子プロセスも含めて確実に回収する
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Info 'bye.'
}
