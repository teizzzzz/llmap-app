"""
Dataset Package（llmap_dataset_*.zip）の導入 API（Step 15 で全面改修）。

ディスク占用を増やさない導入フロー:
  1. zip を data/tmp/ に**ストリーミング**で受ける（メモリに全載せしない）
  2. 整包 SHA-256 を計算 → 既存 Dataset と照合（重複導入の検出）
  3. data/tmp/ 内に展開して検証（zip slip 拒否・必須ファイル）
  4. 写真は正式目录へ **rename で移動**（同一ファイルシステム前提）。
     同名ファイルが既にある場合は SHA-256 を比較し、
     同内容なら再保存せず共用、別内容なら安全な別名に振り直す
  5. SQLite に記録を登録して commit
  6. **zip と展開目录を即削除**（「保管する」指定時のみ zip を archives/ へ）

旧フロー（imports/ に zip＋展開目录を永久保存）は 2〜3 倍のディスク占用を
生んでいた。既存の imports/ 遺留は /storage/cleanup（storage_api.py）で回収する。
"""
from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from .database import archives_dir, photos_dir, source_photos_dir, tmp_dir
from .database import get_session
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


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _unique_dest(dest_dir: Path, file_name: str) -> Path:
    """同名別内容の衝突時に使う安全な別名（stem~2.ext, stem~3.ext, …）。"""
    stem = Path(file_name).stem
    ext = Path(file_name).suffix
    n = 2
    while True:
        cand = dest_dir / f"{stem}~{n}{ext}"
        if not cand.exists():
            return cand
        n += 1


def _place_photo(src: Path, dest_dir: Path, file_name: str) -> tuple[str, bool]:
    """展開済み写真を正式目录へ配置する。戻り値は (実際の保存名, 再利用したか)。
    - 同名なし → rename 移動（同一 FS なので複製コスト無し）
    - 同名・同内容 → 移動せず既存を共用（内容去重）
    - 同名・別内容 → 別名に振り直して移動（既存データを壊さない）
    """
    dest = dest_dir / file_name
    if dest.exists():
        if sha256_file(dest) == sha256_file(src):
            return file_name, True
        dest = _unique_dest(dest_dir, file_name)
    os.replace(src, dest)
    return dest.name, False


@router.post("/datasets/import")
async def import_dataset(
    file: UploadFile = File(...),
    mode: str = Form("ask"),  # ask | fill_missing（重複包の扱い）
    keepOriginal: bool = Form(False),  # True なら zip を archives/ に保管
    session: Session = Depends(get_session),
):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    work = tmp_dir() / f"import_{ts}"
    work.mkdir(parents=True, exist_ok=True)
    zip_path = work / _safe_name(file.filename)
    try:
        # 1) ストリーミング受信（file.read() の全量メモリ読みはしない）
        with open(zip_path, "wb") as out:
            shutil.copyfileobj(file.file, out, length=1024 * 1024)

        # 2) 整包指紋 → 重複導入の検出
        package_hash = sha256_file(zip_path)
        dup = session.exec(
            select(Dataset).where(Dataset.package_hash == package_hash)).first()
        if dup is not None and mode == "ask":
            # SignID は全体一意のため「新データセットとして再導入」は成立しない
            # （全行 skip になる）。選択肢は 跳过 / 欠落写真の補充 のみ。
            return {
                "status": "duplicate",
                "packageHash": package_hash,
                "existingDatasetId": dup.id,
                "existingDatasetName": dup.name,
                "existingImportedAt": dup.imported_at.isoformat(),
            }

        # 3) 展開と検証
        extract_dir = work / "extracted"
        try:
            with zipfile.ZipFile(zip_path) as zf:
                _safe_extract(zf, extract_dir)
        except zipfile.BadZipFile:
            raise HTTPException(400, "zip として読み込めませんでした")

        csv_path = extract_dir / "data.csv"
        if not csv_path.is_file():
            raise HTTPException(400, "data.csv がパッケージ内にありません")
        metadata = _read_json(extract_dir, "metadata.json")
        _read_json(extract_dir, "schema.json")  # 解析可能性のみ検証
        manifest = _read_json(extract_dir, "manifest.json")
        manifest_files = list(manifest.get("files", []))

        if dup is not None and mode == "fill_missing":
            return _fill_missing_photos(session, dup, extract_dir, manifest_files)

        return _import_new(
            session=session,
            file_name=_safe_name(file.filename),
            package_hash=package_hash,
            extract_dir=extract_dir,
            csv_path=csv_path,
            metadata=metadata,
            manifest=manifest,
            manifest_files=manifest_files,
            zip_path=zip_path,
            keep_original=keepOriginal,
        )
    finally:
        # 6) 成功・失敗を問わず一時作業目录を残さない
        shutil.rmtree(work, ignore_errors=True)


def _import_new(
    *, session: Session, file_name: str, package_hash: str, extract_dir: Path,
    csv_path: Path, metadata: dict, manifest: dict,
    manifest_files: list, zip_path: Path, keep_original: bool,
) -> dict:
    warnings: list[str] = []
    for entry in manifest_files:
        rel = str(entry.get("path", ""))
        if rel and not (extract_dir / rel).is_file():
            warnings.append(f"manifest に記載の写真が見つかりません: {rel}")

    dataset = Dataset(
        name=file_name,
        package_hash=package_hash,
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

    try:
        rows = list(csv.DictReader(
            io.StringIO(csv_path.read_text(encoding="utf-8-sig"))))
    except Exception as e:
        raise HTTPException(400, f"data.csv の解析に失敗: {e}")

    duplicate_sign_ids: list[str] = []
    imported = 0
    skipped = 0
    record_by_sign: dict[str, SignRecord] = {}
    # 既存 SignID は1回のクエリでまとめて取得（行ごとの SELECT は遅い）。
    existing_sign_ids = set(session.exec(select(SignRecord.sign_id)).all())
    for i, row in enumerate(rows):
        sign_id = (row.get("SignID") or "").strip()
        if not sign_id:
            skipped += 1
            warnings.append(f"data.csv {i + 2} 行目: SignID が空のため skip")
            continue
        if sign_id in record_by_sign or sign_id in existing_sign_ids:
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

    # 写真の配置（manifest.files を正とする）。rename 移動＋内容去重。
    photo_count = 0
    source_count = 0
    missing_photos = 0
    reused_photos = 0
    renames: dict[str, str] = {}  # 旧名 → 実際の保存名（同名別内容の時のみ）
    for entry in manifest_files:
        rel = str(entry.get("path", ""))
        ptype = str(entry.get("type", "crop"))
        file_name_in_pkg = Path(rel).name
        src = extract_dir / rel
        dest_dir = source_photos_dir() if ptype == "source" else photos_dir()
        found = src.is_file()
        stored_name = file_name_in_pkg
        if found:
            stored_name, reused = _place_photo(src, dest_dir, file_name_in_pkg)
            if reused:
                reused_photos += 1
            if stored_name != file_name_in_pkg:
                renames[file_name_in_pkg] = stored_name
                warnings.append(
                    f"同名別内容のため改名して保存: {file_name_in_pkg} → {stored_name}")
            if ptype == "source":
                source_count += 1
            else:
                photo_count += 1
        else:
            missing_photos += 1
        dest = dest_dir / stored_name
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
            file_name=stored_name,
            size_bytes=dest.stat().st_size if found else 0,
            exists=found,
        ))
    # 改名が発生した場合は、今回導入した記録の参照名も追随させる
    # （CSV の名前のまま残すと表示・照片配信が切れる）。
    if renames:
        for rec in record_by_sign.values():
            changed = False
            data = json.loads(rec.data_json)
            for key, attr in [("写真ファイル名", "photo_file_name"),
                              ("元写真ファイル名", "source_photo_file_name")]:
                old = getattr(rec, attr)
                if old in renames:
                    setattr(rec, attr, renames[old])
                    data[key] = renames[old]
                    changed = True
            if data.get("全景写真ファイル名") in renames:
                data["全景写真ファイル名"] = renames[data["全景写真ファイル名"]]
                changed = True
            if changed:
                rec.data_json = json.dumps(data, ensure_ascii=False)
                session.add(rec)

    for entry in manifest.get("missingFiles", []):
        warnings.append(f"導出時点で欠落していた写真: {entry.get('path', '')}")

    session.commit()

    # 原始包の保管（既定オフ）。オンなら archives/ へ移動、オフなら削除される
    # （呼び出し元 finally の rmtree に任せる）。
    archived_to = None
    if keep_original:
        dest = archives_dir() / f"{dataset.imported_at:%Y%m%d_%H%M%S}_{dataset.name}"
        if not dest.exists():
            os.replace(zip_path, dest)
        archived_to = str(dest)

    return {
        "status": "imported",
        "datasetId": dataset.id,
        "packageHash": package_hash,
        "recordCount": len(rows),
        "importedRecordCount": imported,
        "skippedRecordCount": skipped,
        "photoCount": photo_count,
        "sourcePhotoCount": source_count,
        "reusedPhotoCount": reused_photos,
        "missingPhotoCount": missing_photos,
        "missingSourcePhotoCount": len(manifest.get("sourceMissing", [])),
        "duplicateSignIds": duplicate_sign_ids,
        "warnings": warnings,
        "archivedTo": archived_to,
    }


def _fill_missing_photos(
    session: Session, dataset: Dataset, extract_dir: Path,
    manifest_files: list,
) -> dict:
    """重複包の「欠落写真だけ補充」モード。記録は一切変更しない。"""
    photos = session.exec(
        select(Photo).where(Photo.dataset_id == dataset.id)).all()
    by_name = {p.file_name: p for p in photos}
    restored = 0
    still_missing = 0
    for entry in manifest_files:
        rel = str(entry.get("path", ""))
        name = Path(rel).name
        ptype = str(entry.get("type", "crop"))
        dest_dir = source_photos_dir() if ptype == "source" else photos_dir()
        dest = dest_dir / name
        src = extract_dir / rel
        if dest.exists():
            continue
        if not src.is_file():
            still_missing += 1
            continue
        os.replace(src, dest)
        restored += 1
        p = by_name.get(name)
        if p is not None:
            p.exists = True
            p.size_bytes = dest.stat().st_size
            session.add(p)
    session.commit()
    return {
        "status": "filled",
        "datasetId": dataset.id,
        "restoredPhotoCount": restored,
        "stillMissingCount": still_missing,
    }


@router.get("/datasets")
def list_datasets(session: Session = Depends(get_session)):
    """Dataset 一覧＋相册カード用の実測値（件数・写真容量・封面）。"""
    from sqlmodel import func  # 局所 import（本ファイルは他で func 不使用）

    out = []
    for d in session.exec(select(Dataset)).all():
        live_count = session.exec(
            select(func.count()).select_from(SignRecord)
            .where(SignRecord.dataset_id == d.id)).one()
        photo_bytes = session.exec(
            select(func.coalesce(func.sum(Photo.size_bytes), 0))
            .where(Photo.dataset_id == d.id)).one()
        cover = session.exec(
            select(Photo.file_name)
            .where(Photo.dataset_id == d.id, Photo.type == "crop",
                   Photo.exists == True)  # noqa: E712
            .limit(1)).first()
        out.append({
            **d.model_dump(mode="json"),
            "liveRecordCount": live_count,
            "photoBytes": photo_bytes,
            "coverPhoto": cover,
        })
    return out


def _to_float(v) -> float | None:
    try:
        return float(v) if v not in (None, "") else None
    except (TypeError, ValueError):
        return None
