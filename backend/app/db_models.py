"""
DB モデル（SQLModel）。
- Dataset    : 1回の Dataset Package 導入
- SignRecord : 1件の sign 記録（検索用の核心列＋全字段の data_json）
- Photo      : 導入した写真ファイル（crop / source）
検索・筛选に使う字段だけ列に出し、36列の全字段は data_json に原様保存する。
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class Dataset(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = ""
    imported_at: datetime = Field(default_factory=datetime.now)
    format_version: str = ""
    app_version: str = ""
    schema_version: str = ""
    record_count: int = 0
    photo_count: int = 0
    source_photo_count: int = 0
    normalized_legacy_record_count: int = 0
    missing_photo_count: int = 0
    missing_source_photo_count: int = 0
    metadata_json: str = "{}"


class SignRecord(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    # SignID は全体で一意（重複導入は skip され、導入レポートに記録される）
    sign_id: str = Field(index=True, unique=True)
    capture_id: str = Field(default="", index=True)
    display_id: str = ""
    entry_mode: str = Field(default="", index=True)
    data_status: str = Field(default="", index=True)
    status: str = Field(default="", index=True)  # _status
    area_code: str = Field(default="", index=True)
    collector_id: str = Field(default="", index=True)
    local_seq: str = ""
    crop_suffix: str = ""
    photo_file_name: str = ""
    source_photo_file_name: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    captured_at: str = Field(default="", index=True)  # 'YYYY-MM-DD HH:MM:SS'
    main_language: str = Field(default="", index=True)
    sub_language: str = ""
    schema_version: str = ""
    app_version: str = ""
    data_json: str = "{}"  # CSV 全字段の原様保存（編集時も同期する）
    dataset_id: Optional[int] = Field(default=None, foreign_key="dataset.id", index=True)
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)


class Photo(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    dataset_id: Optional[int] = Field(default=None, foreign_key="dataset.id", index=True)
    record_id: Optional[int] = Field(default=None, foreign_key="signrecord.id", index=True)
    capture_id: str = Field(default="", index=True)
    sign_id: str = ""  # crop のみ（source は複数 sign が共有するため空）
    type: str = "crop"  # 'crop' | 'source'
    original_path_in_package: str = ""
    stored_path: str = ""  # data_dir からの相対パス
    file_name: str = Field(default="", index=True)
    size_bytes: int = 0
    exists: bool = True
    created_at: datetime = Field(default_factory=datetime.now)
