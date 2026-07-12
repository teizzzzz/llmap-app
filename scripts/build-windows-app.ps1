# LLMap Desktop — Windows 一括ビルド（Windows 10/11 実機で実行する）。
#   powershell -ExecutionPolicy Bypass -File scripts\build-windows-app.ps1
#
# 流れ: Console(React) → backend exe(PyInstaller) → sidecar 配置 → Tauri(NSIS)。
# 前提（docs/windows-desktop-build.md §1）:
#   Node.js 18+ / Python 3.11+ / Rust stable (MSVC) / VS C++ Build Tools
# 生成物:
#   desktop\src-tauri\target\release\bundle\nsis\LLMap_*_x64-setup.exe
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "== [1/5] backend tests ==" -ForegroundColor Cyan
Push-Location "$root\backend"
python -m pytest tests -q
Pop-Location

Write-Host "== [2/5] Console build ==" -ForegroundColor Cyan
Push-Location "$root\console"
npm install
npm run build
Pop-Location

Write-Host "== [3/5] backend exe (PyInstaller) ==" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$root\scripts\build-backend-binary.ps1"

Write-Host "== [4/5] sidecar placement ==" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$root\scripts\prepare-tauri-sidecar.ps1"

Write-Host "== [5/5] Tauri build (NSIS installer) ==" -ForegroundColor Cyan
Push-Location "$root\desktop"
npm install
npm run build   # = tauri build（tauri.windows.conf.json は自動マージされる）
Pop-Location

$out = Get-ChildItem "$root\desktop\src-tauri\target\release\bundle\nsis\*-setup.exe" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ""
Write-Host ("done in {0:n0}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
if ($out) {
    Write-Host "installer : $($out.FullName)" -ForegroundColor Green
    Write-Host ("size      : {0:n1} MB" -f ($out.Length / 1MB)) -ForegroundColor Green
} else {
    Write-Warning "NSIS インストーラが見つかりません（desktop\src-tauri\target\release\bundle を確認）"
}
Write-Host "検証手順  : docs/windows-desktop-build.md §7 チェックリスト"
