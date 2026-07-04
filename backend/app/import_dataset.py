"""
Dataset Package（llmap_dataset_*.zip）の導入 API。
- zip を data/imports/ に保存・展開し、data.csv / metadata.json / schema.json /
  manifest.json を検証して SQLite に取り込む。
- 写真は data/photos/（crop）と data/source_photos/（source）へ複製する。
- 旧データはパッケージ側で既に規範化済みなので、ここでは再規範化しない。
- 少数の写真欠落では失敗させない（warnings に記録して続行する）。
"""
from __future__ import annotations

import csv
import io
import json
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlmodel import Session, select

from .database import get_session, imports_dir, photos_dir, source_photos_dir
from .db_models import Dataset, Photo, SignRecord
from .schema import DATA_STATUS_MAP

router = APIRouter(tags=["datasets"])


def _safe_name(name: str) -> str:
    """アップロードファイル名からパス成分を除去する。"""
    return Path(name or "dataset.zip").name.replace("..", "_")


def _safe_extract(zf: zipfile.ZipFile, dest: Path) -> None:
    """zip slip（../ での目录穿越）を拒否して展開する。"""
    for member in zf.namelist():
        p = Path(member)
        if p.is_absolute() or ".." in p.parts:
            raise HTTPException(400, f"不正な zip エントリ: {member}")
    zf.extractall(dest)


def _read_json(root: Path, name: str) -> dict:
    p = root / name
    if not p.is_file():
        raise HTTPException(400, f"{name} がパッケージ内にありません")
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise HTTPException(400, f"{name} の解析に失敗: {e}")


@router.post("/datasets/import")
async def import_dataset(
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
):
    # 1) zip を保存して展開
    ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    zip_path = imports_dir() / f"{ts}_{_safe_name(file.filename)}"
    zip_path.write_bytes(await file.read())
    extract_dir = imports_dir() / zip_path.stem
    try:
        with zipfile.ZipFile(zip_path) as zf:
            _safe_extract(zf, extract_dir)
    except zipfile.BadZipFile:
        raise HTTPException(400, "zip として読み込めませんでした")

    # 2) 必須ファイルの検証
    csv_path = extract_dir / "data.csv"
    if not csv_path.is_file():
        raise HTTPException(400, "data.csv がパッケージ内にありません")
    metadata = _read_json(extract_dir, "metadata.json")
    _read_json(extract_dir, "schema.json")  # 解析可能性のみ検証（将来の互換判定用）
    manifest = _read_json(extract_dir, "manifest.json")

    warnings: list[str] = []

    # 3) manifest の files と実ファイルの照合
    manifest_files = list(manifest.get("files", []))
    for entry in manifest_files:
        rel = str(entry.get("path", ""))
        if rel and not (extract_dir / rel).is_file():
            warnings.append(f"manifest に記載の写真が見つかりません: {rel}")

    # 4) Dataset 行（metadata.json を正とし、無い値は 0/空）
    dataset = Dataset(
        name=_safe_name(file.filename),
        format_version=str(metadata.get("formatVersion", "")),
        app_version=str(metadata.get("appVersion", "")),
        schema_version=str(metadata.get("schemaVersion", "")),
        record_count=int(metadata.get("recordCount", 0) or 0),
        photo_count=int(metadata.get("photoCount", 0) or 0),
        source_photo_count=int(metadata.get("sourcePhotoCount", 0) or 0),
        normalized_legacy_record_count=int(
            metadata.get("normalizedLegacyRecordCount", 0) or 0),
        missing_photo_count=int(metadata.get("missingPhotoCount", 0) or 0),
        missing_source_photo_count=int(
            metadata.get("missingSourcePhotoCount", 0) or 0),
        metadata_json=json.dumps(metadata, ensure_ascii=False),
    )
    session.add(dataset)
    session.flush()

    # 5) data.csv → SignRecord。SignID 重複は静黙上書きせず skip して報告する。
    try:
        rows = list(csv.DictReader(
            io.StringIO(csv_path.read_text(encoding="utf-8-sig"))))
    except Exception as e:
        raise HTTPException(400, f"data.csv の解析に失敗: {e}")

    duplicate_sign_ids: list[str] = []
    imported = 0
    skipped = 0
    record_by_sign: dict[str, SignRecord] = {}
    for i, row in enumerate(rows):
        sign_id = (row.get("SignID") or "").strip()
        if not sign_id:
            skipped += 1
            warnings.append(f"data.csv {i + 2} 行目: SignID が空のため skip")
            continue
        exists_in_db = session.exec(
            select(SignRecord).where(SignRecord.sign_id == sign_id)).first()
        if sign_id in record_by_sign or exists_in_db:
            skipped += 1
            duplicate_sign_ids.append(sign_id)
            continue
        status = (row.get("_status") or "pending").strip()
        data_status = (row.get("DataStatus") or "").strip() or \
            DATA_STATUS_MAP.get(status, "raw")
        rec = SignRecord(
            sign_id=sign_id,
            capture_id=(row.get("CaptureID") or "").strip(),
            display_id=(row.get("DisplayID") or "").strip(),
            entry_mode=(row.get("EntryMode") or "").strip(),
            data_status=data_status,
            status=status,
            area_code=(row.get("地区コード") or "").strip(),
            collector_id=(row.get("採集者ID") or "").strip(),
            local_seq=(row.get("LocalSeq") or "").strip(),
            crop_suffix=(row.get("CropSuffix") or "").strip(),
            photo_file_name=(row.get("写真ファイル名") or "").strip(),
            source_photo_file_name=(row.get("元写真ファイル名") or "").strip(),
            latitude=_to_float(row.get("緯度")),
            longitude=_to_float(row.get("経度")),
            captured_at=(row.get("採集日時") or "").strip(),
            main_language=(row.get("主要言語") or "").strip(),
            sub_language=(row.get("補助言語") or "").strip(),
            schema_version=(row.get("SchemaVersion") or "").strip(),
            app_version=(row.get("AppVersion") or "").strip(),
            data_json=json.dumps(row, ensure_ascii=False),
            dataset_id=dataset.id,
        )
        session.add(rec)
        record_by_sign[sign_id] = rec
        imported += 1
    session.flush()

    # 6) 写真の複製（manifest.files を正とする）。既存同名はコピーしない
    #    （ファイル名は CaptureID ベースで一意 = 同名は同一内容とみなす）。
    photo_count = 0
    source_count = 0
    missing_photos = 0
    for entry in manifest_files:
        rel = str(entry.get("path", ""))
        ptype = str(entry.get("type", "crop"))
        file_name = Path(rel).name
        src = extract_dir / rel
        dest_dir = source_photos_dir() if ptype == "source" else photos_dir()
        dest = dest_dir / file_name
        found = src.is_file()
        if found:
            if not dest.exists():
                shutil.copy2(src, dest)
            if ptype == "source":
                source_count += 1
            else:
                photo_count += 1
        else:
            missing_photos += 1
        sign_id = str(entry.get("signId", ""))
        rec = record_by_sign.get(sign_id)
        session.add(Photo(
            dataset_id=dataset.id,
            record_id=rec.id if rec else None,
            capture_id=str(entry.get("captureId", "")),
            sign_id=sign_id,
            type=ptype,
            original_path_in_package=rel,
            stored_path=str(dest.relative_to(dest_dir.parent)),
            file_name=file_name,
            size_bytes=dest.stat().st_size if found else 0,
            exists=found,
        ))
    # manifest.missingFiles（导出時点で既に欠落）も warnings に反映
    for entry in manifest.get("missingFiles", []):
        warnings.append(f"導出時点で欠落していた写真: {entry.get('path', '')}")

    session.commit()

    return {
        "datasetId": dataset.id,
        "recordCount": len(rows),
        "importedRecordCount": imported,
        "skippedRecordCount": skipped,
        "photoCount": photo_count,
        "sourcePhotoCount": source_count,
        "missingPhotoCount": missing_photos,
        "missingSourcePhotoCount": len(manifest.get("sourceMissing", [])),
        "duplicateSignIds": duplicate_sign_ids,
        "warnings": warnings,
    }


@router.get("/datasets")
def list_datasets(session: Session = Depends(get_session)):
    items = session.exec(select(Dataset)).all()
    return [d.model_dump(mode="json") for d in items]


def _to_float(v) -> float | None:
    try:
        return float(v) if v not in (None, "") else None
    except (TypeError, ValueError):
        return None
