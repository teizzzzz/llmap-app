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


def tmp_dir() -> Path:
    """導入の一時作業目录。data_dir と同一ファイルシステムに置く
    （写真を正式目录へ rename で移せる＝大容量でも複製コストゼロ）。"""
    p = data_dir() / "tmp"
    p.mkdir(parents=True, exist_ok=True)
    return p


def archives_dir() -> Path:
    """「原始 Dataset Package を保管する」オプション（既定オフ）の保存先。"""
    p = data_dir() / "archives"
    p.mkdir(parents=True, exist_ok=True)
    return p


# ── アプリ設定（settings.json） ─────────────────────────────────────
# 例: {"exportDir": "F:\\LLMap\\exports"}。導出先を C 盘（data_dir）以外へ
# 逃がすための設定。破損・欠落は既定値扱い（起動を止めない）。

def _settings_file() -> Path:
    return data_dir() / "settings.json"


def load_settings() -> dict:
    try:
        import json
        return json.loads(_settings_file().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_settings(settings: dict) -> None:
    """原子的に保存（tmp → replace。書き込み中断で設定を失わない）。"""
    import json
    tmp = _settings_file().with_suffix(".json.tmp")
    tmp.write_text(
        json.dumps(settings, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, _settings_file())


def default_exports_dir() -> Path:
    p = data_dir() / "exports"
    p.mkdir(parents=True, exist_ok=True)
    return p


def exports_dir() -> Path:
    """導出ジョブ（Dataset Package / 写真 ZIP）の出力先。
    settings.json の exportDir を優先し、作成不能（ドライブ取り外し等）なら
    既定の data_dir/exports へ静かにフォールバックする（導出を止めない）。"""
    configured = load_settings().get("exportDir")
    if configured:
        p = Path(configured)
        try:
            p.mkdir(parents=True, exist_ok=True)
            return p
        except OSError:
            pass  # 到達不能 → 既定へ
    return default_exports_dir()


# ── 最小マイグレーション層 ──────────────────────────────────────────
# SQLModel の create_all は**新テーブルしか作らない**（既存テーブルへの
# 列追加はしない）。既存 DB に列を足す時は必ずここに ALTER を書き、
# _SCHEMA_VERSION を上げる。PRAGMA user_version で適用済みを判定する。
_SCHEMA_VERSION = 2


def _migrate(engine) -> None:
    with engine.connect() as conn:
        current = conn.exec_driver_sql("PRAGMA user_version").scalar() or 0
        if current >= _SCHEMA_VERSION:
            return
        if current < 2:
            # v2: dataset.package_hash（導入包の SHA-256。重複導入の検出用）
            cols = [r[1] for r in
                    conn.exec_driver_sql("PRAGMA table_info(dataset)")]
            if "package_hash" not in cols:
                conn.exec_driver_sql(
                    "ALTER TABLE dataset ADD COLUMN package_hash "
                    "VARCHAR NOT NULL DEFAULT ''")
                conn.exec_driver_sql(
                    "CREATE INDEX IF NOT EXISTS ix_dataset_package_hash "
                    "ON dataset (package_hash)")
        conn.exec_driver_sql(f"PRAGMA user_version = {_SCHEMA_VERSION}")
        conn.commit()


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
        _migrate(_engine)
    return _engine


def init_db() -> None:
    get_engine()


def get_session():
    with Session(get_engine()) as session:
        yield session
