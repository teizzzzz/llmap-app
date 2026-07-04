"""
SQLite データベース層（Research Console 用のローカルDBサービス）。
- 既定の保存先は backend/data/。環境変数 LLMAP_DATA_DIR で差し替え可（テスト用）。
- PostgreSQL 等は使わない: 毕业設計段階はローカル単体で動くことを優先する。
"""
from __future__ import annotations

import os
from pathlib import Path

from sqlmodel import Session, SQLModel, create_engine

_engine = None


def data_dir() -> Path:
    root = os.environ.get("LLMAP_DATA_DIR")
    base = Path(root) if root else Path(__file__).resolve().parent.parent / "data"
    base.mkdir(parents=True, exist_ok=True)
    return base


def photos_dir() -> Path:
    p = data_dir() / "photos"
    p.mkdir(parents=True, exist_ok=True)
    return p


def source_photos_dir() -> Path:
    p = data_dir() / "source_photos"
    p.mkdir(parents=True, exist_ok=True)
    return p


def imports_dir() -> Path:
    p = data_dir() / "imports"
    p.mkdir(parents=True, exist_ok=True)
    return p


def get_engine():
    global _engine
    if _engine is None:
        db_path = data_dir() / "llmap.sqlite3"
        _engine = create_engine(
            f"sqlite:///{db_path}",
            connect_args={"check_same_thread": False},
        )
        # 初回接続時にテーブルを作成（冪等）。lifespan 経由でなくても壊れない。
        from . import db_models  # noqa: F401  テーブル定義を登録してから create_all

        SQLModel.metadata.create_all(_engine)
    return _engine


def init_db() -> None:
    get_engine()


def get_session():
    with Session(get_engine()) as session:
        yield session
