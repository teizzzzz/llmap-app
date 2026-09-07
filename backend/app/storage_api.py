"""
ストレージの可視化と清掃 API（Step 15）。
- GET  /storage/summary : データ目录のパス・分類別使用量・ディスク残量・回収可能量
- POST /storage/cleanup : 旧導入フローが残した imports/（zip＋展開目录）と
                          tmp/ の遺留を削除する。dryRun=true なら削除せず見積のみ。

安全規則:
- 正式資産（photos/ source_photos/ SQLite archives/）には**一切触れない**。
- 削除前に「DB が exists=true とする全写真が正式目录に実在する」ことを検証し、
  1件でも欠けていれば削除を拒否して欠落一覧を返す（imports/ が唯一の
  復旧源かもしれないため）。欠落は /datasets/import の fill_missing で補充できる。
"""
from __future__ import annotations

import shutil
from pathlib import Path

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy import delete, func
from sqlmodel import Session, select

from .database import (
    archives_dir, data_dir, exports_dir, get_engine, imports_dir,
    photos_dir, source_photos_dir, tmp_dir, get_session,
)
from .db_models import Dataset, Photo, SignRecord

router = APIRouter(tags=["storage"])


def _dir_size(path: Path) -> int:
    if not path.exists():
        return 0
    total = 0
    for p in path.rglob("*"):
        try:
            if p.is_file():
                total += p.stat().st_size
        except OSError:
            continue
    return total


def _imports_entries() -> list[Path]:
    p = data_dir() / "imports"
    if not p.exists():
        return []
    return sorted(p.iterdir())


def _reclaimable_paths() -> list[Path]:
    """削除対象: imports/ 直下のすべて（旧フローの zip＋展開目录。導入完了後は
    どのコードからも参照されない）＋ tmp/ の中断遺留。"""
    out = list(_imports_entries())
    for p in tmp_dir().iterdir():
        out.append(p)
    return out


def _verify_photos(session: Session) -> list[str]:
    """DB が exists=true とする写真が正式目录に実在するか。欠落名を返す。"""
    missing: list[str] = []
    for p in session.exec(select(Photo).where(Photo.exists == True)).all():  # noqa: E712
        base = source_photos_dir() if p.type == "source" else photos_dir()
        f = base / p.file_name
        if not f.is_file() or f.stat().st_size == 0:
            missing.append(f"{p.type}/{p.file_name}")
    return missing


@router.get("/storage/summary")
def storage_summary(session: Session = Depends(get_session)):
    root = data_dir()
    db_file = root / "llmap.sqlite3"
    usage = shutil.disk_usage(root)
    reclaim = _reclaimable_paths()
    reclaim_bytes = sum(
        _dir_size(p) if p.is_dir() else p.stat().st_size for p in reclaim)
    return {
        "dataDir": str(root),
        "categories": {
            "photos": _dir_size(photos_dir()),
            "sourcePhotos": _dir_size(source_photos_dir()),
            "database": db_file.stat().st_size if db_file.exists() else 0,
            "imports": _dir_size(root / "imports"),
            "archives": _dir_size(archives_dir()),
            "exports": _dir_size(exports_dir()),
            "tmp": _dir_size(tmp_dir()),
        },
        "diskTotal": usage.total,
        "diskFree": usage.free,
        "reclaimableBytes": reclaim_bytes,
        "reclaimableEntries": [str(p.name) for p in reclaim],
    }


@router.post("/storage/cleanup")
def storage_cleanup(
    payload: dict = Body(default={}),
    session: Session = Depends(get_session),
):
    dry_run = bool(payload.get("dryRun", True))
    missing = _verify_photos(session)
    reclaim = _reclaimable_paths()
    reclaim_bytes = sum(
        _dir_size(p) if p.is_dir() else p.stat().st_size for p in reclaim)

    if missing:
        # imports/ が唯一の復旧源の可能性 → 削除しない。
        return {
            "ok": False,
            "dryRun": dry_run,
            "deleted": 0,
            "reclaimableBytes": reclaim_bytes,
            "missingPhotos": missing[:50],
            "missingPhotoCount": len(missing),
            "message": "正式写真庫に欠落があるため清掃を中止しました。"
                       "重複導入の『欠落写真を補充』で復旧してから再実行してください。",
        }

    deleted = 0
    if not dry_run:
        for p in reclaim:
            if p.is_dir():
                shutil.rmtree(p, ignore_errors=True)
            else:
                try:
                    p.unlink()
                except OSError:
                    continue
            deleted += 1
    return {
        "ok": True,
        "dryRun": dry_run,
        "deleted": deleted,
        "reclaimableBytes": 0 if not dry_run else reclaim_bytes,
        "freedBytes": reclaim_bytes if not dry_run else 0,
        "entries": [p.name for p in reclaim],
        "missingPhotoCount": 0,
    }


@router.post("/storage/reset")
def storage_reset(
    payload: dict = Body(default={}),
    session: Session = Depends(get_session),
):
    """全データ削除（初期化）。記録 DB の全行・写真（crop/source）・導入遺留・
    保管パッケージ・既定フォルダ内の導出物を削除し、SQLite を VACUUM で収縮する。

    残すもの: settings.json（AI キー・導出先設定）と logs/。
    settings.json の exportDir が指す**外部**フォルダには一切触れない
    （ユーザーが選んだ場所で、他のファイルが同居し得るため）。

    誤操作防止: confirm="DELETE" を必須とする（UI 側でも打鍵確認）。"""
    if payload.get("confirm") != "DELETE":
        raise HTTPException(
            400, '全データ削除には confirm="DELETE" が必要です（誤操作防止）')

    count = lambda model: session.exec(  # noqa: E731
        select(func.count()).select_from(model)).one()
    n_records = count(SignRecord)
    n_datasets = count(Dataset)
    n_photos = count(Photo)

    # 削除対象目录（既定 exports のみ — 設定済み外部 exportDir は対象外）。
    wipe_dirs = [
        photos_dir(), source_photos_dir(), imports_dir(),
        archives_dir(), data_dir() / "exports", tmp_dir(),
    ]
    freed = sum(_dir_size(d) for d in wipe_dirs)
    db_file = data_dir() / "llmap.sqlite3"
    db_before = db_file.stat().st_size if db_file.exists() else 0

    # 1) DB 行（FK 順: Photo → SignRecord → Dataset）
    session.execute(delete(Photo))
    session.execute(delete(SignRecord))
    session.execute(delete(Dataset))
    session.commit()

    # 2) ファイル・目录（消してから空で作り直す）
    for d in wipe_dirs:
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True, exist_ok=True)

    # 3) VACUUM で DB ファイルを収縮（失敗しても初期化自体は成立）
    try:
        with get_engine().connect() as conn:
            conn.execution_options(
                isolation_level="AUTOCOMMIT").exec_driver_sql("VACUUM")
    except Exception:  # noqa: BLE001
        pass
    db_after = db_file.stat().st_size if db_file.exists() else 0

    return {
        "ok": True,
        "deletedRecords": n_records,
        "deletedDatasets": n_datasets,
        "deletedPhotos": n_photos,
        "freedBytes": freed + max(0, db_before - db_after),
    }
