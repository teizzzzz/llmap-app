"""
LLMap backend の単体起動エントリポイント（PyInstaller binary 用）。

開発時は従来どおり `uvicorn app.main:app --reload` を使えばよい。
これは桌面 shell（将来の Tauri）や launcher が起動する用の薄い入口で、
Python 未導入の環境でも動く `llmap-backend` binary のエントリになる。

使い方:
    llmap-backend [--host 127.0.0.1] [--port 8000] [--data-dir PATH]

環境変数（CLI 引数が優先）:
    LLMAP_HOST      既定 127.0.0.1（安全のため 0.0.0.0 は既定にしない）
    LLMAP_PORT      既定 8000
    LLMAP_DATA_DIR  データ保存先（DB・写真・導入包）
"""
from __future__ import annotations

import argparse
import os
import sys


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="llmap-backend",
        description="LLMap local backend (FastAPI + SQLite, local-first)",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("LLMAP_HOST", "127.0.0.1"),
        help="bind address (default 127.0.0.1; do NOT expose 0.0.0.0 unless you know why)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("LLMAP_PORT", "8000")),
        help="port (default 8000)",
    )
    parser.add_argument(
        "--data-dir",
        default=os.environ.get("LLMAP_DATA_DIR", ""),
        help="data directory for DB/photos/imports (default: backend/data or LLMAP_DATA_DIR)",
    )
    args = parser.parse_args()

    # data_dir は app モジュール import 前に環境変数へ反映する
    # （app.database が LLMAP_DATA_DIR を読むため）。
    if args.data_dir:
        os.environ["LLMAP_DATA_DIR"] = args.data_dir

    import uvicorn

    from app.database import data_dir
    from app.main import app

    print(f"[llmap-backend] data dir : {data_dir()}", flush=True)
    print(f"[llmap-backend] listening: http://{args.host}:{args.port} "
          f"(health: /health, api docs: /docs)", flush=True)
    if args.host not in ("127.0.0.1", "localhost"):
        print("[llmap-backend] WARNING: 非 localhost で待受しています。"
              "本 backend は認証を持たないため、公開ネットワークに晒さないでください。",
              flush=True)

    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    # PyInstaller onefile では sys.frozen が立つ（挙動は同一。将来の分岐用）。
    if getattr(sys, "frozen", False):
        os.chdir(os.path.dirname(sys.executable))
    main()
