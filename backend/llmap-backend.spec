# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for the LLMap backend binary (Step 10C).
#
# 生成物: dist/llmap-backend（Windows では dist/llmap-backend.exe）
# ビルド: cd backend && pyinstaller llmap-backend.spec
#
# 方針:
# - **one-file** を採用（Tauri sidecar として「単一パスの実行ファイル」を
#   置けるのが最重要。起動時の自己展開コストは §計測で許容範囲を確認済み）。
# - AI プロバイダ SDK（anthropic / google-genai）は**同梱しない**。
#   app/ai.py が関数内で遅延 import しているため除外でき、体積を大きく
#   節約できる。桌面 MVP は /ai を使わない（呼ばれた場合のみ 502 になる）。
# - backend/data・テスト・仮想環境は同梱しない（ユーザーデータは
#   LLMAP_DATA_DIR で外部指定する）。

from PyInstaller.utils.hooks import collect_submodules

hiddenimports = (
    # uvicorn は実行時に文字列でモジュールを解決するため明示する
    collect_submodules("uvicorn")
    # python-multipart（/datasets/import の multipart 解析）
    + ["multipart", "python_multipart"]
    # Pillow の画像プラグイン（JPEG 保存・EXIF）
    + ["PIL.Image", "PIL.ImageOps", "PIL.JpegImagePlugin"]
    # pydantic v2 のネイティブコア
    + ["pydantic_core"]
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
