"""
LLMap 轻后端 (FastAPI)。
Phase 0: EXIF/GPS抽出・字段规整・AI判定・CSV互換を提供。
フロント(Flutter)は採集・框选・地図预览を担当し、ここに写真と框选を渡す。
"""
from __future__ import annotations

import json
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

from . import ai
from .csv_io import signs_to_csv
from .exif import extract_exif, normalize_datetime
from .schema import (
    AI_FIELDS, CSV_HEADER, ENUMS, LANGUAGE_COLORS, STATUS_VALUES,
    CropRegion, Sign, photo_id, sign_id,
)

app = FastAPI(title="LLMap backend", version="0.1.0")

# 単人ローカル開発のため全許可。多人化時に絞る。
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, "service": "llmap-backend", "version": "0.1.0"}


@app.get("/schema")
def get_schema():
    """フロントのフォーム選択肢・地図色・標準表頭を配信。"""
    return {
        "csv_header": CSV_HEADER,
        "status_values": STATUS_VALUES,
        "enums": ENUMS,
        "ai_fields": AI_FIELDS,
        "language_colors": LANGUAGE_COLORS,
    }


@app.post("/extract")
async def extract(
    photo: UploadFile = File(...),
    area: str = Form(...),
    seq: int = Form(...),
    crops: str = Form("[]"),
    fallback_lat: Optional[float] = Form(None),
    fallback_lng: Optional[float] = Form(None),
):
    """
    写真1枚＋框选から sign レコード群を生成する（あなたの③④に対応）。
    - 写真EXIFのGPSを優先、無ければ端末GPS(fallback)を使う。
    - crops が空なら全景1枚を1 sign として扱う。
    """
    data = await photo.read()
    meta = extract_exif(data)
    lat = meta["lat"] if meta["lat"] is not None else fallback_lat
    lng = meta["lng"] if meta["lng"] is not None else fallback_lng
    captured = normalize_datetime(meta["datetime"])

    try:
        raw_crops = json.loads(crops or "[]")
        regions = [CropRegion(**c) for c in raw_crops]
    except Exception as e:
        raise HTTPException(400, f"crops の解析に失敗: {e}")

    pid = photo_id(area, _yyyymmdd(captured), seq)
    pano_name = f"{pid}.jpg"

    if not regions:
        regions = [CropRegion(suffix="a", x=0, y=0, w=1, h=1)]

    signs: list[Sign] = []
    for r in regions:
        is_full = r.w >= 0.999 and r.h >= 0.999
        fname = pano_name if is_full else f"{pid}-{r.suffix}.jpg"
        signs.append(Sign(
            SignID=sign_id(area, seq, r.suffix),
            写真ID=pid,
            写真ファイル名=fname,
            全景写真ファイル名="" if is_full else pano_name,
            緯度=lat, 経度=lng, 採集日時=captured,
            **{"_status": "pending"},
        ))

    return JSONResponse({
        "photo_id": pid,
        "gps": {"lat": lat, "lng": lng, "source":
                "exif" if meta["lat"] is not None else "device"},
        "captured": captured,
        "signs": [s.model_dump(by_alias=True) for s in signs],
    })


@app.post("/ai")
async def ai_judge(
    photo: UploadFile = File(...),
    provider: str = Form("claude"),
    fields: str = Form(""),
    crop_x: Optional[float] = Form(None),
    crop_y: Optional[float] = Form(None),
    crop_w: Optional[float] = Form(None),
    crop_h: Optional[float] = Form(None),
):
    """1枚をAI判定し字段dictを返す（⑥のAI部分）。
    crop_* が揃っていれば全景からその矩形を切り出してから判定する。"""
    data = await photo.read()
    if None not in (crop_x, crop_y, crop_w, crop_h) and not (
        crop_w >= 0.999 and crop_h >= 0.999
    ):
        data = ai.crop_image(data, crop_x, crop_y, crop_w, crop_h)
    field_list = [f for f in fields.split(",") if f.strip()] or None
    try:
        result = ai.judge(data, provider=provider, fields=field_list)
    except RuntimeError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        raise HTTPException(502, f"AI判定に失敗: {e}")
    return {"provider": provider, "fields": result, "_status": "ai"}


@app.post("/export")
def export(signs: list[dict]):
    """sign レコード群を CSV(utf-8-sig) としてダウンロードさせる。"""
    models = [Sign(**s) for s in signs]
    body = signs_to_csv(models).encode("utf-8-sig")
    return Response(
        content=body,
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="llmap_export.csv"'},
    )


def _yyyymmdd(captured: str) -> str:
    """'YYYY-MM-DD HH:MM:SS' → 'YYYYMMDD'。無ければ '00000000'。"""
    if captured and len(captured) >= 10:
        return captured[:10].replace("-", "")
    return "00000000"
