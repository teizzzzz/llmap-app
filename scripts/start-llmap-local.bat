@echo off
rem LLMap developer launcher - Windows 双击入口。
rem 実体は start-llmap-local.ps1（これは呼び出すだけ）。
rem これは最終製品ではありません（最終製品は打包された LLMap.exe）。
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-llmap-local.ps1"
pause
