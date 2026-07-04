"""
基礎統計 API（将来の Dashboard 用）。
GET /stats/summary : 件数・写真・EntryMode/DataStatus/言語/地区/採集者の分布。
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlmodel import Session, func, select

from .database import get_session
from .db_models import Dataset, Photo, SignRecord
from .schema import split_multi

router = APIRouter(tags=["stats"])


def _tally(session: Session, column) -> dict[str, int]:
    rows = session.exec(
        select(column, func.count()).select_from(SignRecord).group_by(column)
    ).all()
    return {(k if k else "unknown"): v for k, v in rows}


@router.get("/stats/summary")
def stats_summary(session: Session = Depends(get_session)):
    record_count = session.exec(
        select(func.count()).select_from(SignRecord)).one()
    dataset_count = session.exec(select(func.count()).select_from(Dataset)).one()

    def photo_count(ptype: str, exists: bool) -> int:
        # 同じ包を重複導入しても写真実体は1つなので、ファイル名で去重して数える。
        return session.exec(
            select(func.count(func.distinct(Photo.file_name)))
            .where(Photo.type == ptype, Photo.exists == exists)).one()

    # 主要言語は「日本語/韓国語」の併記があるため、個々の言語に展開して数える。
    lang_counts: dict[str, int] = {}
    for v in session.exec(select(SignRecord.main_language)).all():
        for p in (split_multi(v) or ["unknown"]):
            lang_counts[p] = lang_counts.get(p, 0) + 1

    return {
        "recordCount": record_count,
        "datasetCount": dataset_count,
        "photoCount": photo_count("crop", True),
        "sourcePhotoCount": photo_count("source", True),
        "missingPhotoCount": photo_count("crop", False),
        "missingSourcePhotoCount": photo_count("source", False),
        "entryModeCounts": _tally(session, SignRecord.entry_mode),
        "dataStatusCounts": _tally(session, SignRecord.data_status),
        "mainLanguageCounts": lang_counts,
        "areaCounts": _tally(session, SignRecord.area_code),
        "collectorCounts": _tally(session, SignRecord.collector_id),
    }
