"""
導出 API。
- GET /export/csv     : 筛选条件で CSV（utf-8-sig・標準36列）
- GET /export/geojson : GPS 付き記録を RFC 7946 FeatureCollection で
  （座標は [経度, 緯度] / WGS84。GPS 無しは feature にせず件数だけ報告）
Dataset Package / 写真 ZIP はジョブ式（export_jobs.py）。
"""
from __future__ import annotations

import csv
import io
import json
from datetime import datetime

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlmodel import Session, col, select

from .database import get_session
from .db_models import SignRecord
from .records_api import apply_filters
from .schema import CSV_HEADER

router = APIRouter(tags=["export"])

# GeoJSON の「精簡」属性（研究の照合に最低限必要な字段）。
_GEOJSON_MINIMAL_PROPS = [
    "SignID", "DisplayID", "CaptureID", "主要言語", "補助言語",
    "EntryMode", "DataStatus", "採集日時", "地区コード", "採集者ID",
]


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


@router.get("/export/geojson")
def export_geojson(
    session: Session = Depends(get_session),
    props: str = "minimal",  # minimal | full
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

    features = []
    total = 0
    skipped_no_gps = 0
    for rec in session.exec(stmt).all():
        total += 1
        if rec.latitude is None or rec.longitude is None:
            skipped_no_gps += 1  # GPS 無しは feature にしない（無音で捨てない）
            continue
        data = json.loads(rec.data_json)
        data["_status"] = rec.status
        data["DataStatus"] = rec.data_status
        if props == "full":
            properties = {k: data.get(k, "") for k in CSV_HEADER}
        else:
            properties = {k: data.get(k, "") for k in _GEOJSON_MINIMAL_PROPS}
        if rec.photo_file_name:
            properties["photo"] = f"photos/{rec.photo_file_name}"
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                # RFC 7946: 座標順は [経度, 緯度]（WGS84）
                "coordinates": [rec.longitude, rec.latitude],
            },
            "properties": properties,
        })

    collection = {
        "type": "FeatureCollection",
        "features": features,
        # RFC 7946 §6.1 foreign members: 導出の来歴と skip 件数を明示する
        "llmap": {
            "generatedAt": datetime.now().isoformat(timespec="seconds"),
            "totalMatched": total,
            "featureCount": len(features),
            "skippedNoGps": skipped_no_gps,
            "props": props,
            "crs": "WGS84 (EPSG:4326)",
        },
    }
    return Response(
        content=json.dumps(collection, ensure_ascii=False).encode("utf-8"),
        media_type="application/geo+json",
        headers={
            "Content-Disposition": 'attachment; filename="llmap_records.geojson"'
        },
    )
