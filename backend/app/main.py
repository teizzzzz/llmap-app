"""
LLMap 轻后端 (FastAPI)。
Phase 0: EXIF/GPS抽出・字段规整・AI判定・CSV互換を提供。
フロント(Flutter)は採集・框选・地図预览を担当し、ここに写真と框选を渡す。
"""
from __future__ import annotations

import io
import json
import zipfile
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

from . import ai, storage
from .csv_io import signs_to_csv
from .exif import extract_exif, normalize_datetime
from .schema import (
    AI_FIELDS, CSV_HEADER, ENUMS, LANGUAGE_COLORS, MULTI_FIELDS, STATUS_VALUES,
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
        "multi_fields": MULTI_FIELDS,
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
    # 全景を永続保存（後で CSV+写真 を一括エクスポートするため）
    pano_name = storage.save_panorama(pid, data)

    if not regions:
        regions = [CropRegion(suffix="a", x=0, y=0, w=1, h=1)]

    signs: list[Sign] = []
    for r in regions:
        is_full = r.w >= 0.999 and r.h >= 0.999
        if is_full:
            fname = pano_name
        else:
            # 裁切写真も保存し、ファイル名を CSV と一致させる
            fname = storage.save_crop(pid, r.suffix, data, r.x, r.y, r.w, r.h)
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
    api_key: Optional[str] = Form(None),
    crop_x: Optional[float] = Form(None),
    crop_y: Optional[float] = Form(None),
    crop_w: Optional[float] = Form(None),
    crop_h: Optional[float] = Form(None),
):
    """1枚をAI判定し字段dictを返す（⑥のAI部分）。
    crop_* が揃っていれば全景からその矩形を切り出してから判定する。
    api_key 未指定時は環境変数を使う。"""
    data = await photo.read()
    if None not in (crop_x, crop_y, crop_w, crop_h) and not (
        crop_w >= 0.999 and crop_h >= 0.999
    ):
        data = ai.crop_image(data, crop_x, crop_y, crop_w, crop_h)
    field_list = [f for f in fields.split(",") if f.strip()] or None
    try:
        result = ai.judge(data, provider=provider, fields=field_list,
                          api_key=api_key or None)
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


@app.post("/export_bundle")
def export_bundle(signs: list[dict]):
    """CSV と参照写真を 1つの ZIP にまとめて返す（一括エクスポート）。
    data.csv ＋ photos/<写真ファイル名/全景写真ファイル名> を同梱する。
    後続の一括プレビューや DB 統合の交換フォーマットとして使う。"""
    models = [Sign(**s) for s in signs]
    csv_bytes = signs_to_csv(models).encode("utf-8-sig")

    wanted: set[str] = set()
    for s in models:
        for key in ("写真ファイル名", "全景写真ファイル名"):
            name = s.model_dump(by_alias=True).get(key) or ""
            if name:
                wanted.add(name)

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("data.csv", csv_bytes)
        added, missing = 0, []
        for name in sorted(wanted):
            if storage.exists(name):
                zf.write(storage.photo_path(name), f"photos/{name}")
                added += 1
            else:
                missing.append(name)
        # 何が入っていないかを残しておく（無音の欠落を避ける）
        manifest = (
            f"records: {len(models)}\n"
            f"photos_included: {added}\n"
            f"photos_missing: {len(missing)}\n"
            + "".join(f"  - {m}\n" for m in missing)
        )
        zf.writestr("MANIFEST.txt", manifest)

    return Response(
        content=buf.getvalue(),
        media_type="application/zip",
        headers={
            "Content-Disposition": 'attachment; filename="llmap_export.zip"'
        },
    )


def _yyyymmdd(captured: str) -> str:
    """'YYYY-MM-DD HH:MM:SS' → 'YYYYMMDD'。無ければ '00000000'。"""
    if captured and len(captured) >= 10:
        return captured[:10].replace("-", "")
    return "00000000"
