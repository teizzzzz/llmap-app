# LLMap backend binary ビルド（Windows）。
# 生成物: backend\dist\llmap-backend.exe
# 注意: PyInstaller はクロスビルド不可 — Windows 用 exe は Windows でビルドする。
#       杀毒ソフトの误报があり得る（docs/backend-binary-build.md 参照）。
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $RepoRoot 'backend')
try {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $python) { Write-Host 'ERROR: python が必要です' -ForegroundColor Red; exit 1 }

    & $python.Source -c 'import fastapi, uvicorn, sqlmodel' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[build] backend 依存を導入します'
        & $python.Source -m pip install -r requirements.txt
    }
    & $python.Source -c 'import PyInstaller' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[build] PyInstaller を導入します'
        & $python.Source -m pip install pyinstaller
    }

    Write-Host '[build] pyinstaller llmap-backend.spec'
    & $python.Source -m PyInstaller --noconfirm llmap-backend.spec
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host '[build] done:'
    Get-Item 'dist\llmap-backend.exe' | Format-List Name, Length
    Write-Host '[build] 動作確認例:'
    Write-Host '  $env:LLMAP_DATA_DIR="$env:TEMP\llmap-test"; .\dist\llmap-backend.exe --port 8010'
}
finally { Pop-Location }
