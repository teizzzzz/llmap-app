# Tauri sidecar 準備（Windows）。
# backend/dist/llmap-backend.exe を Tauri v2 の externalBin 命名規則
# （llmap-backend-<target triple>.exe）で desktop/src-tauri/binaries/ に配置する。
# 先に .\scripts\build-backend-binary.ps1 で exe をビルドしておくこと。
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $RepoRoot 'backend\dist\llmap-backend.exe'
if (-not (Test-Path $Src)) {
    Write-Host "ERROR: $Src がありません。先に scripts\build-backend-binary.ps1 を実行してください。" -ForegroundColor Red
    exit 1
}

# rustc からホストの target triple を取得（例 x86_64-pc-windows-msvc）
$triple = (& rustc -vV | Select-String '^host: ').ToString().Split(' ')[1]
if (-not $triple) { Write-Host 'ERROR: rustc が見つかりません（Rust を導入してください）。' -ForegroundColor Red; exit 1 }

$DestDir = Join-Path $RepoRoot 'desktop\src-tauri\binaries'
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
$Dest = Join-Path $DestDir "llmap-backend-$triple.exe"
Copy-Item $Src $Dest -Force
Write-Host "[sidecar] copied: $Dest"
