"""
記録の検索・閲覧・編集・写真配信・地図用 API。
- GET  /records            : 分页＋検索＋筛选
- GET  /records/{id}       : 全字段（data_json）＋写真URL＋dataset 情報
- PATCH /records/{id}      : 研究字段と _status/DataStatus の編集（系統字段はロック）
- GET  /records/{id}/photo | /source-photo : 写真配信
- GET  /photos/{filename}  : ファイル名直接配信（目录穿越は拒否）
- GET  /map/records        : GPS を持つ記録のみの軽量リスト
"""
from __future__ import annotations

import json
from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlmodel import Session, col, func, select

from .database import get_session, photos_dir, source_photos_dir
from .db_models import Dataset, SignRecord
from .schema import (
    CSV_HEADER, DATA_STATUS_MAP, DATA_STATUS_VALUES, MULTI_FIELDS,
    STATUS_VALUES, SYSTEM_FIELDS,
)

router = APIRouter(tags=["records"])

# 編集可能字段: 研究字段（CSV表頭のうち系統字段以外）＋ _status / DataStatus。
# 系統字段（SignID/CaptureID/採集者ID/採集日時/写真名/SchemaVersion/AppVersion 等）
# は既定でロックする。GPS 修正等の特例が必要になったら個別に検討する（TODO）。
EDITABLE_FIELDS = ({f for f in CSV_HEADER} - set(SYSTEM_FIELDS)) | {
    "_status", "DataStatus",
}


# 字段筛选で使える字段 = 研究字段（系統字段以外の CSV 表頭）。
# 値は data_json にのみ持つため json_extract で照合する。
FILTERABLE_FIELDS = {f for f in CSV_HEADER} - set(SYSTEM_FIELDS)


def _field_filters(value) -> dict[str, list[str]]:
    """fields パラメータの正規化。

    GET では JSON 文字列（例 '{"担体類型":"无媒介"}'）、POST（導出ジョブ・AI）
    では dict がそのまま来る。値は文字列 or 文字列配列を許容する。
    未知の字段名は 400（黙って条件を落とすと「筛选したつもりで全件導出」
    という事故になるため、明示的に拒否する）。
    """
    if value is None or value == "":
        return {}
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            raise HTTPException(400, f"fields が JSON として読めません: {value!r}")
    if not isinstance(value, dict):
        raise HTTPException(400, "fields はオブジェクトで指定してください")
    out: dict[str, list[str]] = {}
    for field, v in value.items():
        if field not in FILTERABLE_FIELDS:
            raise HTTPException(
                400, f"筛选できない字段です（研究字段のみ可）: {field}")
        vals = [str(x) for x in (v if isinstance(v, (list, tuple)) else [v])
                if str(x).strip() != ""]
        if vals:
            out[field] = vals
    return out


def _dataset_id_list(value) -> list[int]:
    """datasetIds の正規化: "1,3" / [1, 3] / 3 → [1, 3]。無効な要素は無視。"""
    if value is None or value == "":
        return []
    if isinstance(value, int):
        return [value]
    parts = value if isinstance(value, (list, tuple)) else str(value).split(",")
    out: list[int] = []
    for p in parts:
        try:
            out.append(int(str(p).strip()))
        except ValueError:
            continue
    return out


def apply_filters(
    stmt,
    *,
    q: str | None = None,
    main_language: str | None = None,
    area_code: str | None = None,
    collector_id: str | None = None,
    entry_mode: str | None = None,
    data_status: str | None = None,
    status: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    has_gps: bool | None = None,
    has_photo: bool | None = None,
    has_source_photo: bool | None = None,
    dataset_id: int | None = None,
    dataset_ids=None,
    field_filters=None,
):
    """/records・/map/records・/export/csv で共用する筛选。"""
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            col(SignRecord.sign_id).like(like)
            | col(SignRecord.capture_id).like(like)
            | col(SignRecord.display_id).like(like)
            | col(SignRecord.data_json).like(like))
    # 主要言語は複数選択（"日本語/韓国語"）のため含有判定にする。
    if main_language:
        stmt = stmt.where(col(SignRecord.main_language).like(f"%{main_language}%"))
    if area_code:
        stmt = stmt.where(SignRecord.area_code == area_code)
    if collector_id:
        stmt = stmt.where(SignRecord.collector_id == collector_id)
    if entry_mode:
        stmt = stmt.where(SignRecord.entry_mode == entry_mode)
    # dataStatus はカンマ区切りの複数値を許容する（Review 队列が
    # raw,submitted,ai_drafted をまとめて分页取得するため。単値は従来どおり）。
    if data_status:
        values = [v.strip() for v in data_status.split(",") if v.strip()]
        if len(values) == 1:
            stmt = stmt.where(SignRecord.data_status == values[0])
        elif values:
            stmt = stmt.where(col(SignRecord.data_status).in_(values))
    if status:
        stmt = stmt.where(SignRecord.status == status)
    # 採集日時は 'YYYY-MM-DD HH:MM:SS' 固定書式なので文字列比較でよい。
    if date_from:
        stmt = stmt.where(SignRecord.captured_at >= date_from)
    if date_to:
        upper = date_to + (" 23:59:59" if len(date_to) == 10 else "")
        stmt = stmt.where(SignRecord.captured_at <= upper)
    if has_gps is True:
        stmt = stmt.where(col(SignRecord.latitude).is_not(None),
                          col(SignRecord.longitude).is_not(None))
    elif has_gps is False:
        stmt = stmt.where(col(SignRecord.latitude).is_(None)
                          | col(SignRecord.longitude).is_(None))
    if has_photo is True:
        stmt = stmt.where(SignRecord.photo_file_name != "")
    elif has_photo is False:
        stmt = stmt.where(SignRecord.photo_file_name == "")
    if has_source_photo is True:
        stmt = stmt.where(SignRecord.source_photo_file_name != "")
    elif has_source_photo is False:
        stmt = stmt.where(SignRecord.source_photo_file_name == "")
    # データセットは複数選択可（導出の多选）。datasetIds があれば優先し、
    # 従来の単値 datasetId は後方互換として残す。
    ids = _dataset_id_list(dataset_ids)
    if not ids and dataset_id is not None:
        ids = [dataset_id]
    if len(ids) == 1:
        stmt = stmt.where(SignRecord.dataset_id == ids[0])
    elif ids:
        stmt = stmt.where(col(SignRecord.dataset_id).in_(ids))
    # 研究字段（字段表の字段）での筛选。値は data_json にのみあるため
    # SQLite JSON1 の json_extract で照合する。複数選択字段（"日本語/英語"）
    # は含有判定、それ以外は完全一致（複数値は OR）。
    for field, vals in _field_filters(field_filters).items():
        extracted = func.json_extract(SignRecord.data_json, f'$."{field}"')
        if field in MULTI_FIELDS:
            cond = None
            for v in vals:
                c = extracted.like(f"%{v}%")
                cond = c if cond is None else (cond | c)
            stmt = stmt.where(cond)
        elif len(vals) == 1:
            stmt = stmt.where(extracted == vals[0])
        else:
            stmt = stmt.where(extracted.in_(vals))
    return stmt


def _item(rec: SignRecord) -> dict:
    """一覧用の1件（キーは CSV 正準キーに揃える）。"""
    return {
        "id": rec.id,
        "SignID": rec.sign_id,
        "CaptureID": rec.capture_id,
        "DisplayID": rec.display_id,
        "EntryMode": rec.entry_mode,
        "DataStatus": rec.data_status,
        "_status": rec.status,
        "主要言語": rec.main_language,
        "補助言語": rec.sub_language,
        "地区コード": rec.area_code,
        "採集者ID": rec.collector_id,
        "採集日時": rec.captured_at,
        "緯度": rec.latitude,
        "経度": rec.longitude,
        "写真ファイル名": rec.photo_file_name,
        "元写真ファイル名": rec.source_photo_file_name,
        "thumbnailUrl": f"/records/{rec.id}/photo" if rec.photo_file_name else None,
    }


@router.get("/records")
def list_records(
    session: Session = Depends(get_session),
    page: int = Query(1, ge=1),
    pageSize: int = Query(50, ge=1, le=500),
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
    datasetIds: str | None = None,
    fields: str | None = None,
):
    kw = dict(
        q=q, main_language=mainLanguage, area_code=areaCode,
        collector_id=collectorId, entry_mode=entryMode, data_status=dataStatus,
        status=status, date_from=dateFrom, date_to=dateTo, has_gps=hasGps,
        has_photo=hasPhoto, has_source_photo=hasSourcePhoto,
        dataset_id=datasetId, dataset_ids=datasetIds, field_filters=fields,
    )
    total = session.exec(
        apply_filters(select(func.count()).select_from(SignRecord), **kw)).one()
    stmt = apply_filters(select(SignRecord), **kw) \
        .order_by(col(SignRecord.captured_at).desc(), col(SignRecord.id).desc()) \
        .offset((page - 1) * pageSize).limit(pageSize)
    items = session.exec(stmt).all()
    return {
        "items": [_item(r) for r in items],
        "page": page,
        "pageSize": pageSize,
        "total": total,
    }


def _get_record(session: Session, record_id: int) -> SignRecord:
    rec = session.get(SignRecord, record_id)
    if rec is None:
        raise HTTPException(404, f"record {record_id} が見つかりません")
    return rec


@router.get("/records/{record_id}")
def get_record(record_id: int, session: Session = Depends(get_session)):
    rec = _get_record(session, record_id)
    dataset = session.get(Dataset, rec.dataset_id) if rec.dataset_id else None
    return {
        **_item(rec),
        "data": json.loads(rec.data_json),
        "photoUrl": f"/records/{rec.id}/photo" if rec.photo_file_name else None,
        "sourcePhotoUrl":
            f"/records/{rec.id}/source-photo" if rec.source_photo_file_name else None,
        "dataset": dataset.model_dump(mode="json") if dataset else None,
        "createdAt": rec.created_at.isoformat(),
        "updatedAt": rec.updated_at.isoformat(),
    }


@router.patch("/records/{record_id}")
def patch_record(
    record_id: int,
    payload: dict = Body(...),
    session: Session = Depends(get_session),
):
    rec = _get_record(session, record_id)
    rejected = [k for k in payload if k not in EDITABLE_FIELDS]
    if rejected:
        raise HTTPException(
            400, f"編集できない字段です（系統字段は既定でロック）: {rejected}")

    # 状態値は既知の枚挙に限定する（未知値が入ると審核队列・統計から
    # 静黙に漏れるため、API 層でも拒否する。UI 側の制約と二重防御）。
    if "_status" in payload and payload["_status"] not in STATUS_VALUES:
        raise HTTPException(
            400, f"不正な _status です（許容値: {STATUS_VALUES}）: "
                 f"{payload['_status']!r}")
    if "DataStatus" in payload and payload["DataStatus"] not in DATA_STATUS_VALUES:
        raise HTTPException(
            400, f"不正な DataStatus です（許容値: {DATA_STATUS_VALUES}）: "
                 f"{payload['DataStatus']!r}")

    data = json.loads(rec.data_json)
    for k, v in payload.items():
        data[k] = "" if v is None else str(v)

    # _status を変えたのに DataStatus 未指定なら対応値に同期（アプリと同じ規則）。
    if "_status" in payload and "DataStatus" not in payload:
        data["DataStatus"] = DATA_STATUS_MAP.get(data["_status"], "raw")

    # 核心列へ反映（検索・筛选の整合を保つ）。
    rec.status = data.get("_status", rec.status)
    rec.data_status = data.get("DataStatus", rec.data_status)
    rec.main_language = data.get("主要言語", rec.main_language)
    rec.sub_language = data.get("補助言語", rec.sub_language)
    rec.data_json = json.dumps(data, ensure_ascii=False)
    rec.updated_at = datetime.now()
    session.add(rec)
    session.commit()
    session.refresh(rec)
    return get_record(rec.id, session)


# ── 写真配信 ──

def _serve(base_dir, name: str):
    """写真ファイルを配信する。名前は必ず検証する（DB の値も導入 CSV 由来で
    信頼できないため、`../` 等での目录穿越をここで一律拒否する）。"""
    if not name or "/" in name or "\\" in name or ".." in name:
        raise HTTPException(400, f"不正なファイル名です: {name}")
    path = base_dir / name
    if not path.is_file():
        raise HTTPException(404, f"写真が見つかりません: {name}")
    return FileResponse(path, media_type="image/jpeg")


@router.get("/records/{record_id}/photo")
def record_photo(record_id: int, session: Session = Depends(get_session)):
    rec = _get_record(session, record_id)
    if not rec.photo_file_name:
        raise HTTPException(404, "この記録に写真がありません")
    return _serve(photos_dir(), rec.photo_file_name)


@router.get("/records/{record_id}/source-photo")
def record_source_photo(record_id: int, session: Session = Depends(get_session)):
    rec = _get_record(session, record_id)
    if not rec.source_photo_file_name:
        raise HTTPException(404, "この記録に元写真がありません")
    return _serve(source_photos_dir(), rec.source_photo_file_name)


@router.get("/photos/{filename}")
def photo_by_name(filename: str):
    # 目录穿越の拒否: パス区切りや .. を含む名前は受け付けない。
    if "/" in filename or "\\" in filename or ".." in filename:
        raise HTTPException(400, "不正なファイル名です")
    for base in (photos_dir(), source_photos_dir()):
        p = base / filename
        if p.is_file():
            return FileResponse(p, media_type="image/jpeg")
    raise HTTPException(404, f"写真が見つかりません: {filename}")


# ── 地図用の軽量リスト ──

@router.get("/map/records")
def map_records(
    session: Session = Depends(get_session),
    mainLanguage: str | None = None,
    areaCode: str | None = None,
    entryMode: str | None = None,
    dataStatus: str | None = None,
    datasetId: int | None = None,
    datasetIds: str | None = None,
):
    stmt = apply_filters(
        select(SignRecord),
        main_language=mainLanguage, area_code=areaCode, entry_mode=entryMode,
        data_status=dataStatus, dataset_id=datasetId, dataset_ids=datasetIds,
        has_gps=True,
    )
    return [
        {
            "id": r.id,
            "signId": r.sign_id,
            "displayId": r.display_id,
            "lat": r.latitude,
            "lng": r.longitude,
            "mainLanguage": r.main_language,
            "dataStatus": r.data_status,
            "entryMode": r.entry_mode,
            "photoUrl": f"/records/{r.id}/photo" if r.photo_file_name else None,
        }
        for r in session.exec(stmt).all()
    ]
