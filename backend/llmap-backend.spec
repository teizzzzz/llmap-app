# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for the LLMap backend binary (Step 10C / 10E).
#
# 生成物:
#   one-file（既定）: dist/llmap-backend（Windows では dist/llmap-backend.exe）
#   one-dir（LLMAP_PYI_ONEDIR=1）: dist/llmap-backend/（実行体 + _internal/）
# ビルド: cd backend && pyinstaller llmap-backend.spec
#
# 方針:
# - 既定は **one-file**（Tauri sidecar として「単一パスの実行ファイル」を
#   置けるのが最重要。起動時の自己展開コストは Linux/Windows では許容範囲）。
# - **macOS は one-dir を使う（Step 10E 実測）**: one-file は起動のたびに
#   dylib 群を新規ファイルとして展開し、macOS がその都度コード署名検証を
#   行うため /health ready まで毎回 15〜25 秒かかる（M4 Pro 実測）。
#   one-dir は展開済みファイルを使い回すので 2 回目以降 ~1 秒で ready になる。
# - AI プロバイダ SDK（anthropic / google-genai）は**同梱しない**。
#   app/ai.py が関数内で遅延 import しているため除外でき、体積を大きく
#   節約できる。桌面 MVP は /ai を使わない（呼ばれた場合のみ 502 になる）。
# - backend/data・テスト・仮想環境は同梱しない（ユーザーデータは
#   LLMAP_DATA_DIR で外部指定する）。

import os

from PyInstaller.utils.hooks import collect_submodules

# one-dir モード（macOS 向け。scripts/build-backend-binary.sh が設定する）
ONEDIR = os.environ.get("LLMAP_PYI_ONEDIR") == "1"

hiddenimports = (
    # uvicorn は実行時に文字列でモジュールを解決するため明示する
    collect_submodules("uvicorn")
    # python-multipart（/datasets/import の multipart 解析）
    + ["multipart", "python_multipart"]
    # pydantic v2 のネイティブコア
    + ["pydantic_core"]
    # Pillow は旧 /extract・/ai の削除（Step 14）に伴い同梱不要になった
)

a = Analysis(
    ["run_backend.py"],
    pathex=["."],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=[
        # AI SDK は遅延 import のため除外（体積節約。/ai 使用時のみ必要）
        "anthropic", "google", "google.genai",
        # 不要な大物
        "tkinter", "unittest", "pytest", "numpy",
    ],
    noarchive=False,
)

pyz = PYZ(a.pure)

if ONEDIR:
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name="llmap-backend",
        debug=False,
        strip=False,
        upx=False,
        console=True,
        disable_windowed_traceback=False,
    )
    coll = COLLECT(
        exe,
        a.binaries,
        a.datas,
        name="llmap-backend",
        strip=False,
        upx=False,
    )
else:
    exe = EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.datas,
        [],
        name="llmap-backend",
        debug=False,
        strip=False,
        upx=False,  # UPX は Windows の杀毒误报を悪化させるため使わない
        console=True,
        disable_windowed_traceback=False,
    )
