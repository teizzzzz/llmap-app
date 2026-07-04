"""
導出 API。
GET /export/csv : 現在の筛选条件で DB から CSV（utf-8-sig・標準36列）を書き出す。
Dataset Package の再導出（ZIP）は後続 Step で扱う。
"""
from __future__ import annotations

import csv
import io
import json

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlmodel import Session, col, select

from .database import get_session
from .db_models import SignRecord
from .records_api import apply_filters
from .schema import CSV_HEADER

router = APIRouter(tags=["export"])


@router.get("/export/csv")
def export_csv(
    session: Session = Depends(get_session),
    q: str | None = None,
    mainLanguage: str | None = None,
    areaCode: str | None = None,
    collectorId: str | None = None,
    entryMode: str | None = None,
    dataStatus: str | None = None,
    status: str | None = None,
    dateFrom: str | None = None,
    dateTo: str | None = None,
    hasGps: bool | None = None,
    hasPhoto: bool | None = None,
    hasSourcePhoto: bool | None = None,
    datasetId: int | None = None,
):
    stmt = apply_filters(
        select(SignRecord),
        q=q, main_language=mainLanguage, area_code=areaCode,
        collector_id=collectorId, entry_mode=entryMode, data_status=dataStatus,
        status=status, date_from=dateFrom, date_to=dateTo, has_gps=hasGps,
        has_photo=hasPhoto, has_source_photo=hasSourcePhoto,
        dataset_id=datasetId,
    ).order_by(col(SignRecord.captured_at), col(SignRecord.id))

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=CSV_HEADER, extrasaction="ignore")
    writer.writeheader()
    for rec in session.exec(stmt).all():
        row = json.loads(rec.data_json)
        # 編集後の核心列を反映（data_json は PATCH で同期済みだが念のため上書き）
        row["_status"] = rec.status
        row["DataStatus"] = rec.data_status
        writer.writerow({k: row.get(k, "") for k in CSV_HEADER})

    return Response(
        content=buf.getvalue().encode("utf-8-sig"),
        media_type="text/csv",
        headers={
            "Content-Disposition": 'attachment; filename="llmap_records.csv"'
        },
    )
