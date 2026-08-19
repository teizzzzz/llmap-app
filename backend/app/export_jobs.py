"""
導出ジョブ（Step 16）: Dataset Package / 写真 ZIP をバックグラウンドで構築する。
- 数 GB になり得るためメモリ上に組まない: 一時ファイルへ zipfile で逐次書き、
  完成後に exports/ へ rename してからダウンロードさせる。
- 進捗（done/total）・取消・完了後ダウンロードを提供する。
- 写真は SHA-256 で内容去重: 同一内容のファイルは ZIP に 1 回しか入れない。
- 欠落写真は無音で捨てず manifest の missingFiles / レポートに残す。

API:
  POST /export/package        {filters...}                      → {jobId}
  POST /export/photos        {filters..., content, naming}      → {jobId}
  GET  /export/jobs/{id}                                        → 進捗
  POST /export/jobs/{id}/cancel
  GET  /export/jobs/{id}/download                               → zip
"""
from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import threading
import uuid
import zipfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Body, HTTPException
from fastapi.responses import FileResponse
from sqlmodel import Session, col, select

from .database import exports_dir, get_engine, photos_dir, source_photos_dir
from .db_models import SignRecord
from .records_api import apply_filters
from .schema import (
    AI_FIELDS, CSV_HEADER, ENUMS, LANGUAGE_COLORS, MULTI_FIELDS, STATUS_VALUES,
)

router = APIRouter(tags=["export-jobs"])


@dataclass
class ExportJob:
    id: str
    kind: str  # 'package' | 'photos'
    status: str = "running"  # running | done | error | cancelled
    done: int = 0
    total: int = 0
    file_name: str = ""
    path: Path | None = None
    size_bytes: int = 0
    error: str = ""
    report: dict = field(default_factory=dict)
    cancel_event: threading.Event = field(default_factory=threading.Event)


_JOBS: dict[str, ExportJob] = {}
_JOBS_LOCK = threading.Lock()


class _Cancelled(Exception):
    pass


def _filters_kwargs(payload: dict) -> dict:
    """Console の RecordsQuery（camelCase）→ apply_filters の引数。"""
    def b(v):
        return None if v is None else bool(v)
    return dict(
        q=payload.get("q") or None,
        main_language=payload.get("mainLanguage") or None,
        area_code=payload.get("areaCode") or None,
        collector_id=payload.get("collectorId") or None,
        entry_mode=payload.get("entryMode") or None,
        data_status=payload.get("dataStatus") or None,
        status=payload.get("status") or None,
        date_from=payload.get("dateFrom") or None,
        date_to=payload.get("dateTo") or None,
        has_gps=b(payload.get("hasGps")),
        has_photo=b(payload.get("hasPhoto")),
        has_source_photo=b(payload.get("hasSourcePhoto")),
        dataset_id=payload.get("datasetId"),
        # 多选（配列 or "1,3"）。単値 datasetId と併用時は datasetIds 優先。
        dataset_ids=payload.get("datasetIds"),
    )


def _load_records(session: Session, filters: dict) -> list[SignRecord]:
    stmt = apply_filters(select(SignRecord), **filters) \
        .order_by(col(SignRecord.captured_at), col(SignRecord.id))
    return list(session.exec(stmt).all())


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _rows_csv(records: list[SignRecord]) -> str:
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=CSV_HEADER, extrasaction="ignore")
    w.writeheader()
    for rec in records:
        row = json.loads(rec.data_json)
        row["_status"] = rec.status
        row["DataStatus"] = rec.data_status
        w.writerow({k: row.get(k, "") for k in CSV_HEADER})
    return buf.getvalue()


def _start(kind: str, worker) -> dict:
    job = ExportJob(id=uuid.uuid4().hex[:12], kind=kind)
    with _JOBS_LOCK:
        _JOBS[job.id] = job

    def run():
        try:
            worker(job)
            if job.status == "running":
                job.status = "done"
        except _Cancelled:
            job.status = "cancelled"
        except Exception as e:  # ジョブはプロセスを巻き込まない
            job.status = "error"
            job.error = str(e)

    threading.Thread(target=run, daemon=True).start()
    return {"jobId": job.id}


def _check_cancel(job: ExportJob, tmp: Path) -> None:
    if job.cancel_event.is_set():
        tmp.unlink(missing_ok=True)
        raise _Cancelled()


# ── Dataset Package（完全再導出。mobile の包構造と互換） ──────────────


def _build_package(job: ExportJob, filters: dict) -> None:
    stamp = datetime.now()
    name = f"llmap_dataset_{stamp:%Y%m%d_%H%M%S}.zip"
    tmp = exports_dir() / f".{name}.part"
    final = exports_dir() / name

    with Session(get_engine()) as session:
        records = _load_records(session, filters)

    # 写真一覧（crop は記録ごと、source は CaptureID 単位で共有 → 名前で去重）
    photo_entries: list[dict] = []  # manifest.files
    missing_files: list[dict] = []
    source_missing: list[str] = []
    seen_zip_paths: set[str] = set()
    for rec in records:
        for fname, ptype, base in [
            (rec.photo_file_name, "crop", photos_dir()),
            (rec.source_photo_file_name, "source", source_photos_dir()),
        ]:
            if not fname:
                if ptype == "source":
                    source_missing.append(rec.sign_id)
                continue
            zpath = ("photos/" if ptype == "crop" else "source_photos/") + fname
            if zpath in seen_zip_paths:
                continue
            seen_zip_paths.add(zpath)
            src = base / fname
            entry = {
                "path": zpath,
                "type": ptype,
                "signId": rec.sign_id if ptype == "crop" else "",
                "captureId": rec.capture_id,
            }
            if src.is_file():
                entry["sizeBytes"] = src.stat().st_size
                entry["sha256"] = ""  # 書き込み時に埋める
                entry["exists"] = True
                entry["_src"] = str(src)
                photo_entries.append(entry)
            else:
                missing_files.append(entry)

    job.total = len(photo_entries)
    csv_text = _rows_csv(records)

    metadata = {
        "format": "LLMap Dataset Package",
        "formatVersion": "1.0",
        "appVersion": "console-export",
        "schemaVersion": records[0].schema_version if records else "1.5",
        "exportedAt": stamp.isoformat(timespec="seconds"),
        "recordCount": len(records),
        "photoCount": sum(1 for e in photo_entries if e["type"] == "crop"),
        "sourcePhotoCount": sum(1 for e in photo_entries if e["type"] == "source"),
        "missingPhotoCount": len(missing_files),
        "missingSourcePhotoCount":
            sum(1 for e in missing_files if e["type"] == "source"),
        "normalizedLegacyRecordCount": 0,
        "filters": {k: v for k, v in filters.items() if v is not None},
    }
    schema_json = {
        "schemaVersion": metadata["schemaVersion"],
        "csv_header": CSV_HEADER,
        "status_values": STATUS_VALUES,
        "enums": ENUMS,
        "ai_fields": AI_FIELDS,
        "language_colors": LANGUAGE_COLORS,
        "multi_fields": MULTI_FIELDS,
    }

    enc = json.JSONEncoder(ensure_ascii=False, indent=2).encode
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("data.csv", "﻿" + csv_text)
            for entry in photo_entries:
                _check_cancel(job, tmp)
                src = Path(entry.pop("_src"))
                entry["sha256"] = _sha256_file(src)
                zf.write(src, entry["path"])
                job.done += 1
            manifest = {
                "formatVersion": "1.0",
                "files": photo_entries,
                "missingFiles": missing_files,
                "sourceMissing": source_missing,
                "normalizedLegacyRecords": [],
            }
            zf.writestr("metadata.json", enc(metadata))
            zf.writestr("schema.json", enc(schema_json))
            zf.writestr("manifest.json", enc(manifest))
            zf.writestr("MANIFEST.txt", _manifest_txt(metadata, missing_files))
            zf.writestr("README.md", _readme())
    except _Cancelled:
        raise
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    os.replace(tmp, final)
    job.file_name = name
    job.path = final
    job.size_bytes = final.stat().st_size
    job.report = {
        "recordCount": len(records),
        "photoCount": metadata["photoCount"],
        "sourcePhotoCount": metadata["sourcePhotoCount"],
        "missingPhotoCount": len(missing_files),
    }


def _manifest_txt(metadata: dict, missing: list[dict]) -> str:
    lines = [
        "LLMap Dataset Package (console export)",
        f"exportedAt: {metadata['exportedAt']}",
        f"records: {metadata['recordCount']}",
        f"photos: {metadata['photoCount']} (+{metadata['sourcePhotoCount']} source)",
        f"missing: {metadata['missingPhotoCount']}",
    ]
    lines += [f"  - {m['path']}" for m in missing[:50]]
    return "\n".join(lines) + "\n"


def _readme() -> str:
    return (
        "# LLMap Dataset Package\n\n"
        "Exported from LLMap Research Console.\n"
        "- data.csv: all records (UTF-8 with BOM, canonical 36-column header)\n"
        "- photos/, source_photos/: referenced images\n"
        "- manifest.json: per-file sha256/size; missingFiles lists photos that\n"
        "  were absent in the library at export time (not silently dropped)\n"
    )


# ── 写真 ZIP ─────────────────────────────────────────────────────────


def _build_photos_zip(job: ExportJob, filters: dict,
                      content: str, naming: str) -> None:
    stamp = datetime.now()
    name = f"llmap_photos_{stamp:%Y%m%d_%H%M%S}.zip"
    tmp = exports_dir() / f".{name}.part"
    final = exports_dir() / name

    with Session(get_engine()) as session:
        records = _load_records(session, filters)

    want_crop = content in ("crop", "both")
    want_source = content in ("source", "both")

    # 追加予定ファイル（記録ごと）。内容去重は書き込み時に sha256 で行う。
    plan: list[tuple[SignRecord, str, Path, str]] = []  # (rec, type, src, zipname)
    used_names: set[str] = set()
    missing: list[str] = []

    def zip_name(rec: SignRecord, ptype: str, original: str) -> str:
        prefix = "photos/" if ptype == "crop" else "source_photos/"
        ext = Path(original).suffix or ".jpg"
        if naming == "signid":
            base = rec.sign_id + ("-source" if ptype == "source" else "")
        elif naming == "displayid":
            base = (rec.display_id or rec.sign_id) + \
                ("-source" if ptype == "source" else "")
        else:
            return prefix + original
        cand = f"{prefix}{base}{ext}"
        n = 2
        while cand in used_names:  # DisplayID 重複などの衝突は安全に連番回避
            cand = f"{prefix}{base}~{n}{ext}"
            n += 1
        return cand

    seen_zip: set[str] = set()
    for rec in records:
        for fname, ptype, base_dir, wanted in [
            (rec.photo_file_name, "crop", photos_dir(), want_crop),
            (rec.source_photo_file_name, "source", source_photos_dir(),
             want_source),
        ]:
            if not wanted or not fname:
                continue
            src = base_dir / fname
            if not src.is_file():
                missing.append(f"{ptype}/{fname}")
                continue
            # original 命名では同一 source の重複計画を名前で先に抑止
            zname = zip_name(rec, ptype, fname)
            if naming == "original" and zname in seen_zip:
                continue
            seen_zip.add(zname)
            used_names.add(zname)
            plan.append((rec, ptype, src, zname))

    job.total = len(plan)

    # photo_mapping.csv（記録 → zip 内ファイルの対応表）
    mapping: dict[str, dict] = {}
    for rec in records:
        mapping[rec.sign_id] = {
            "SignID": rec.sign_id,
            "DisplayID": rec.display_id,
            "CaptureID": rec.capture_id,
            "照片文件": "",
            "原图文件": "",
        }

    hash_to_zipname: dict[str, str] = {}
    added = 0
    deduped = 0
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zf:
            for rec, ptype, src, zname in plan:
                _check_cancel(job, tmp)
                digest = _sha256_file(src)
                stored = hash_to_zipname.get(digest)
                if stored is None:
                    zf.write(src, zname)
                    hash_to_zipname[digest] = zname
                    stored = zname
                    added += 1
                else:
                    deduped += 1  # 同一内容は 1 回だけ（異名の同写真も含む）
                key = "照片文件" if ptype == "crop" else "原图文件"
                if rec.sign_id in mapping:
                    mapping[rec.sign_id][key] = stored
                job.done += 1
            map_buf = io.StringIO()
            w = csv.DictWriter(map_buf, fieldnames=[
                "SignID", "DisplayID", "CaptureID", "照片文件", "原图文件"])
            w.writeheader()
            for row in mapping.values():
                w.writerow(row)
            zf.writestr("photo_mapping.csv", "﻿" + map_buf.getvalue())
            if missing:
                zf.writestr("MISSING.txt",
                            "\n".join(missing) + "\n")
    except _Cancelled:
        raise
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    os.replace(tmp, final)
    job.file_name = name
    job.path = final
    job.size_bytes = final.stat().st_size
    job.report = {
        "recordCount": len(records),
        "filesAdded": added,
        "dedupedFiles": deduped,
        "missingCount": len(missing),
    }


# ── エンドポイント ───────────────────────────────────────────────────


@router.post("/export/package")
def start_package_export(payload: dict = Body(default={})):
    filters = _filters_kwargs(payload)
    return _start("package", lambda job: _build_package(job, filters))


@router.post("/export/photos")
def start_photos_export(payload: dict = Body(default={})):
    filters = _filters_kwargs(payload)
    content = payload.get("content", "both")
    naming = payload.get("naming", "original")
    if content not in ("crop", "source", "both"):
        raise HTTPException(400, f"不正な content: {content}")
    if naming not in ("signid", "displayid", "original"):
        raise HTTPException(400, f"不正な naming: {naming}")
    return _start(
        "photos",
        lambda job: _build_photos_zip(job, filters, content, naming))


def _get_job(job_id: str) -> ExportJob:
    job = _JOBS.get(job_id)
    if job is None:
        raise HTTPException(404, f"ジョブが見つかりません: {job_id}")
    return job


@router.get("/export/jobs/{job_id}")
def job_status(job_id: str):
    job = _get_job(job_id)
    return {
        "id": job.id,
        "kind": job.kind,
        "status": job.status,
        "done": job.done,
        "total": job.total,
        "fileName": job.file_name,
        # 生成先のフルパス（導出目录設定の可視化。Console が「〜に生成しました」を出す）
        "path": str(job.path) if job.path is not None else "",
        "sizeBytes": job.size_bytes,
        "error": job.error,
        "report": job.report,
    }


@router.post("/export/jobs/{job_id}/cancel")
def job_cancel(job_id: str):
    job = _get_job(job_id)
    if job.status == "running":
        job.cancel_event.set()
    return {"ok": True, "status": job.status}


@router.get("/export/jobs/{job_id}/download")
def job_download(job_id: str):
    job = _get_job(job_id)
    if job.status != "done" or job.path is None or not job.path.is_file():
        raise HTTPException(409, f"ジョブは未完了です（status={job.status}）")
    return FileResponse(
        job.path,
        media_type="application/zip",
        filename=job.file_name,
    )
