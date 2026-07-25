"""
LLMap backend (FastAPI) — Research Console 用ローカル DB サービス。
- Dataset Package 導入・検索/筛选・編集・写真配信・地図・統計・CSV導出（SQLite）。
- 旧 Phase 0 の採集補助エンドポイント（/extract・/ai・/export・/export_bundle）は
  Step 14 で削除した: モバイルは C 計画（v1.1）以降端末内で完結しており、
  どのクライアントからも呼ばれていなかった（未使用の入口は攻撃面になるだけ）。
  端末側の対応クライアント（api.dart）も同時に削除済み。
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import init_db
from .schema import (
    AI_FIELDS, CSV_HEADER, ENUMS, LANGUAGE_COLORS, MULTI_FIELDS, STATUS_VALUES,
)
from . import (
    ai_jobs, config_api, export_api, export_jobs, import_dataset,
    records_api, stats_api, storage_api,
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="LLMap backend", version="0.6.2", lifespan=lifespan)

app.include_router(import_dataset.router)
app.include_router(records_api.router)
app.include_router(stats_api.router)
app.include_router(export_api.router)
app.include_router(export_jobs.router)
app.include_router(storage_api.router)
app.include_router(config_api.router)
app.include_router(ai_jobs.router)

# 単人ローカル開発のため全許可。多人化時に絞る。
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, "service": "llmap-backend", "version": "0.6.2"}


@app.get("/schema")
def get_schema():
    """フロントのフォーム選択肢・地図色・標準表頭を配信。"""
    return {
        "csv_header": CSV_HEADER,
        "status_values": STATUS_VALUES,
        "enums": ENUMS,
        "ai_fields": AI_FIELDS,
        "language_colors": LANGUAGE_COLORS,
        "multi_fields": MULTI_FIELDS,
    }
