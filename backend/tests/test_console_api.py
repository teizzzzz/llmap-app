"""
Research Console API（Step 4）の統合テスト。
Dataset Package ZIP を実際に組み立てて導入→検索→編集→写真→地図→統計→導出を検証する。
実行: cd backend && python -m pytest tests/ -q
"""
from __future__ import annotations

import csv
import io
import json
import os
import tempfile
import zipfile

# LLMAP_DATA_DIR は app.database の import 前に設定する（DB/写真の隔離）。
os.environ["LLMAP_DATA_DIR"] = tempfile.mkdtemp(prefix="llmap_test_")

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.schema import CSV_HEADER  # noqa: E402

client = TestClient(app)

JPEG = b"\xff\xd8\xff\xe0" + b"llmap-test-jpeg" * 10 + b"\xff\xd9"

CAPTURE = "OOK-7Kx9Qp2A-260701143512482"
LEGACY_CAPTURE = "OOK-legacy-260701150000000"


def _row(**kw) -> dict:
    row = {k: "" for k in CSV_HEADER}
    row.update(kw)
    return row


def make_package(rows, files, manifest_extra=None) -> bytes:
    """rows: CSV 行 / files: {zip内パス: bytes}。manifest は files から生成する。"""
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=CSV_HEADER)
    w.writeheader()
    for r in rows:
        w.writerow(r)

    manifest = {
        "formatVersion": "1.0",
        "files": [
            {
                "path": p,
                "type": "source" if p.startswith("source_photos/") else "crop",
                "signId": sid,
                "captureId": cid,
                "exists": True,
                "sizeBytes": len(files.get(p, b"")),
            }
            for p, sid, cid in manifest_extra or []
        ],
        "missingFiles": [],
        "sourceMissing": [],
        "normalizedLegacyRecords": [],
    }
    metadata = {
        "format": "LLMap Dataset Package",
        "formatVersion": "1.0",
        "appVersion": "v1.8.0",
        "schemaVersion": "1.5",
        "recordCount": len(rows),
    }
    schema = {"schemaVersion": "1.5", "headers": CSV_HEADER}

    zbuf = io.BytesIO()
    with zipfile.ZipFile(zbuf, "w") as zf:
        zf.writestr("data.csv", "﻿" + buf.getvalue())
        zf.writestr("metadata.json", json.dumps(metadata, ensure_ascii=False))
        zf.writestr("schema.json", json.dumps(schema, ensure_ascii=False))
        zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False))
        zf.writestr("README.md", "# test package")
        for path, data in files.items():
            zf.writestr(path, data)
    return zbuf.getvalue()


def default_package() -> bytes:
    rows = [
        _row(SignID=f"{CAPTURE}-a", _status="pending", CaptureID=CAPTURE,
             DisplayID="OOK-20260701-008-a", 採集者ID="7Kx9Qp2A",
             地区コード="OOK", LocalSeq="8", CropSuffix="a",
             CropRect='{"x":0,"y":0,"w":1,"h":1}',
             写真ファイル名=f"{CAPTURE}-a.jpg",
             元写真ファイル名=f"{CAPTURE}-source.jpg",
             緯度="35.6021", 経度="139.7011",
             採集日時="2026-07-01 14:35:12", 主要言語="韓国語/日本語",
             EntryMode="standard", DataStatus="submitted",
             SchemaVersion="1.5", AppVersion="v1.8.0"),
        _row(SignID=f"{CAPTURE}-b", _status="pending", CaptureID=CAPTURE,
             DisplayID="OOK-20260701-008-b", 採集者ID="7Kx9Qp2A",
             地区コード="OOK", CropSuffix="b",
             写真ファイル名=f"{CAPTURE}-b.jpg",
             元写真ファイル名=f"{CAPTURE}-source.jpg",
             採集日時="2026-07-01 14:35:12", 主要言語="日本語",
             EntryMode="quick", DataStatus="raw",
             SchemaVersion="1.5", AppVersion="v1.8.0"),
        # 旧データ（規範化済み・DataStatus 空 → _status から補完される）
        _row(SignID=f"{LEGACY_CAPTURE}-a", _status="human-reviewed",
             CaptureID=LEGACY_CAPTURE, DisplayID="OOK-S010-a",
             採集者ID="legacy", 地区コード="OOK", CropSuffix="a",
             写真ファイル名=f"{LEGACY_CAPTURE}-a.jpg",
             採集日時="2026-07-01 15:00:00", 主要言語="中国語"),
    ]
    files = {
        f"photos/{CAPTURE}-a.jpg": JPEG,
        f"photos/{CAPTURE}-b.jpg": JPEG,
        f"source_photos/{CAPTURE}-source.jpg": JPEG,
        # LEGACY の crop は manifest に載せるが実体を入れない（欠落テスト）
    }
    manifest_entries = [
        (f"photos/{CAPTURE}-a.jpg", f"{CAPTURE}-a", CAPTURE),
        (f"photos/{CAPTURE}-b.jpg", f"{CAPTURE}-b", CAPTURE),
        (f"source_photos/{CAPTURE}-source.jpg", "", CAPTURE),
        (f"photos/{LEGACY_CAPTURE}-a.jpg", f"{LEGACY_CAPTURE}-a", LEGACY_CAPTURE),
    ]
    return make_package(rows, files, manifest_entries)


def _import(pkg: bytes):
    return client.post(
        "/datasets/import",
        files={"file": ("llmap_dataset_test.zip", pkg, "application/zip")},
    )


def test_import_dataset_package():
    r = _import(default_package())
    assert r.status_code == 200, r.text
    rep = r.json()
    assert rep["recordCount"] == 3
    assert rep["importedRecordCount"] == 3
    assert rep["skippedRecordCount"] == 0
    assert rep["photoCount"] == 2          # 実在の crop 2 枚
    assert rep["sourcePhotoCount"] == 1
    assert rep["missingPhotoCount"] == 1   # LEGACY crop は実体なし
    assert rep["duplicateSignIds"] == []
    assert any("見つかりません" in w for w in rep["warnings"])  # 欠落は warning


def test_photos_saved_to_storage():
    from app.database import photos_dir, source_photos_dir
    assert (photos_dir() / f"{CAPTURE}-a.jpg").is_file()
    assert (photos_dir() / f"{CAPTURE}-b.jpg").is_file()
    assert (source_photos_dir() / f"{CAPTURE}-source.jpg").is_file()


def test_reimport_reports_duplicates():
    r = _import(default_package())
    assert r.status_code == 200
    rep = r.json()
    assert rep["importedRecordCount"] == 0
    assert rep["skippedRecordCount"] == 3
    assert sorted(rep["duplicateSignIds"]) == sorted(
        [f"{CAPTURE}-a", f"{CAPTURE}-b", f"{LEGACY_CAPTURE}-a"])


def test_records_pagination():
    r = client.get("/records", params={"page": 1, "pageSize": 2})
    body = r.json()
    assert body["total"] == 3
    assert len(body["items"]) == 2
    r2 = client.get("/records", params={"page": 2, "pageSize": 2})
    assert len(r2.json()["items"]) == 1


def test_data_status_multi_value_filter():
    # Review 队列用: カンマ区切りで複数 DataStatus をまとめて取得できる。
    multi = client.get("/records", params={"dataStatus": "raw,submitted"}).json()
    single_raw = client.get("/records", params={"dataStatus": "raw"}).json()
    single_sub = client.get("/records", params={"dataStatus": "submitted"}).json()
    assert multi["total"] == single_raw["total"] + single_sub["total"]
    assert multi["total"] >= 2


def test_records_filters():
    assert client.get("/records", params={"entryMode": "quick"}).json()["total"] == 1
    assert client.get("/records", params={"dataStatus": "submitted"}).json()["total"] == 1
    # 併記（韓国語/日本語）も含有判定で当たる
    assert client.get("/records", params={"mainLanguage": "日本語"}).json()["total"] == 2
    assert client.get("/records", params={"hasGps": "true"}).json()["total"] == 1
    assert client.get("/records", params={"hasSourcePhoto": "false"}).json()["total"] == 1
    assert client.get("/records", params={"q": LEGACY_CAPTURE}).json()["total"] == 1


def test_legacy_data_status_fallback():
    r = client.get("/records", params={"q": f"{LEGACY_CAPTURE}-a"})
    item = r.json()["items"][0]
    assert item["DataStatus"] == "reviewed"  # human-reviewed から補完


def test_get_record_detail():
    rid = client.get("/records", params={"q": f"{CAPTURE}-a"}).json()["items"][0]["id"]
    r = client.get(f"/records/{rid}")
    body = r.json()
    assert body["SignID"] == f"{CAPTURE}-a"
    assert body["data"]["CropRect"] == '{"x":0,"y":0,"w":1,"h":1}'
    assert body["photoUrl"] == f"/records/{rid}/photo"
    assert body["sourcePhotoUrl"] == f"/records/{rid}/source-photo"
    assert body["dataset"]["schema_version"] == "1.5"


def test_patch_research_fields():
    rid = client.get("/records", params={"q": f"{CAPTURE}-a"}).json()["items"][0]["id"]
    r = client.patch(f"/records/{rid}", json={"主要言語": "英語", "備考": "編集テスト",
                                              "_status": "human-reviewed"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["主要言語"] == "英語"
    assert body["data"]["備考"] == "編集テスト"
    assert body["_status"] == "human-reviewed"
    assert body["DataStatus"] == "reviewed"  # _status から自動同期


def test_patch_system_fields_locked():
    rid = client.get("/records", params={"q": f"{CAPTURE}-b"}).json()["items"][0]["id"]
    for field in ["SignID", "CaptureID", "採集者ID", "採集日時",
                  "写真ファイル名", "元写真ファイル名", "SchemaVersion", "AppVersion"]:
        r = client.patch(f"/records/{rid}", json={field: "hacked"})
        assert r.status_code == 400, field


def test_photo_endpoints():
    rid = client.get("/records", params={"q": f"{CAPTURE}-a"}).json()["items"][0]["id"]
    assert client.get(f"/records/{rid}/photo").status_code == 200
    assert client.get(f"/records/{rid}/source-photo").status_code == 200
    assert client.get(f"/photos/{CAPTURE}-a.jpg").status_code == 200
    # 欠落写真は 404
    legacy_id = client.get(
        "/records", params={"q": f"{LEGACY_CAPTURE}-a"}).json()["items"][0]["id"]
    assert client.get(f"/records/{legacy_id}/photo").status_code == 404
    assert client.get(f"/records/{legacy_id}/source-photo").status_code == 404
    # 目录穿越は拒否
    assert client.get("/photos/..%2Fllmap.sqlite3").status_code in (400, 404)


def test_record_photo_traversal_rejected():
    # DB の写真名が汚染されていても（導入 CSV 由来）、record 経由の配信で
    # 目录穿越できない。
    from sqlmodel import Session, select
    from app.database import get_engine
    from app.db_models import SignRecord

    with Session(get_engine()) as s:
        s.add(SignRecord(sign_id="EVIL-traversal-a",
                         photo_file_name="../llmap.sqlite3",
                         source_photo_file_name="..\\llmap.sqlite3",
                         data_json="{}"))
        s.commit()
        rid = s.exec(select(SignRecord)
                     .where(SignRecord.sign_id == "EVIL-traversal-a")).first().id
    assert client.get(f"/records/{rid}/photo").status_code == 400
    assert client.get(f"/records/{rid}/source-photo").status_code == 400
    # 後続テスト（stats の件数）に影響しないよう掃除する。
    with Session(get_engine()) as s:
        s.delete(s.get(SignRecord, rid))
        s.commit()


def test_map_records_gps_only():
    r = client.get("/map/records")
    items = r.json()
    assert len(items) == 1  # GPS を持つのは 1 件だけ
    assert items[0]["signId"] == f"{CAPTURE}-a"
    assert items[0]["lat"] and items[0]["lng"]
    assert client.get("/map/records", params={"entryMode": "quick"}).json() == []


def test_stats_summary():
    s = client.get("/stats/summary").json()
    assert s["recordCount"] == 3
    assert s["datasetCount"] == 2  # 重複導入分も dataset 行は増える
    assert s["photoCount"] == 2
    assert s["sourcePhotoCount"] == 1
    assert s["missingPhotoCount"] >= 1
    assert s["entryModeCounts"]["quick"] == 1
    assert s["dataStatusCounts"]["reviewed"] == 2  # legacy 補完 + PATCH 昇格
    assert s["mainLanguageCounts"]["英語"] == 1   # PATCH 後の値
    assert s["areaCounts"]["OOK"] == 3


def test_export_csv():
    r = client.get("/export/csv", params={"areaCode": "OOK"})
    assert r.status_code == 200
    text = r.content.decode("utf-8-sig")
    rows = list(csv.DictReader(io.StringIO(text)))
    assert len(rows) == 3
    assert rows[0].keys() == dict.fromkeys(CSV_HEADER).keys()
    edited = [x for x in rows if x["SignID"] == f"{CAPTURE}-a"][0]
    assert edited["主要言語"] == "英語"  # 編集が導出に反映される
    # 筛选付き導出
    r2 = client.get("/export/csv", params={"entryMode": "quick"})
    assert len(list(csv.DictReader(io.StringIO(r2.content.decode("utf-8-sig"))))) == 1


def test_ai_status_disabled():
    # AI バッチは scaffold のみ: 常に disabled・プロバイダ空・実呼び出しなし。
    s = client.get("/ai/status").json()
    assert s["enabled"] is False
    assert s["providers"] == []
    assert "not configured" in s["message"]


def test_broken_package_rejected():
    # manifest.json が壊れている
    zbuf = io.BytesIO()
    with zipfile.ZipFile(zbuf, "w") as zf:
        zf.writestr("data.csv", "SignID\nX-1")
        zf.writestr("metadata.json", "{}")
        zf.writestr("schema.json", "{}")
        zf.writestr("manifest.json", "{broken json")
    r = _import(zbuf.getvalue())
    assert r.status_code == 400
    assert "manifest.json" in r.json()["detail"]
    # data.csv が無い
    zbuf2 = io.BytesIO()
    with zipfile.ZipFile(zbuf2, "w") as zf:
        zf.writestr("metadata.json", "{}")
    r2 = _import(zbuf2.getvalue())
    assert r2.status_code == 400
    assert "data.csv" in r2.json()["detail"]
