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


def _zi(name: str) -> zipfile.ZipInfo:
    """固定日時の ZipInfo。writestr(str, …) は現在時刻を DOS 時刻（2秒精度）で
    エントリに埋め込むため、同じ内容でも 2 秒境界をまたいで再構築すると
    バイト列が変わり、整包 SHA-256 の重複検出テストが時々落ちる。"""
    return zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))


def make_package(rows, files, manifest_extra=None) -> bytes:
    """rows: CSV 行 / files: {zip内パス: bytes}。manifest は files から生成する。
    zip は固定日時で構築し、呼ぶたびにバイト同一（決定的）にする。"""
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
        zf.writestr(_zi("data.csv"), "﻿" + buf.getvalue())
        zf.writestr(_zi("metadata.json"), json.dumps(metadata, ensure_ascii=False))
        zf.writestr(_zi("schema.json"), json.dumps(schema, ensure_ascii=False))
        zf.writestr(_zi("manifest.json"), json.dumps(manifest, ensure_ascii=False))
        zf.writestr(_zi("README.md"), "# test package")
        for path, data in files.items():
            zf.writestr(_zi(path), data)
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


def test_reimport_same_package_detected_by_hash():
    """まったく同じ zip → 整包 SHA-256 で検出。何も導入しない（Step 15）。"""
    r = _import(default_package())
    assert r.status_code == 200
    rep = r.json()
    assert rep["status"] == "duplicate"
    assert rep["existingDatasetId"] == 1
    assert rep["existingDatasetName"]
    # dataset 行は増えない
    assert len(client.get("/datasets").json()) == 1


def test_reimport_reports_duplicates():
    """内容の異なる包（指紋が変わる）に既存 SignID → 行レベルで skip。"""
    rows = [
        _row(SignID=f"{CAPTURE}-a", _status="pending", CaptureID=CAPTURE,
             地区コード="OOK", 採集日時="2026-07-01 14:35:12",
             主要言語="韓国語"),
    ]
    r = _import(make_package(rows, {}, []))
    assert r.status_code == 200
    rep = r.json()
    assert rep["status"] == "imported"
    assert rep["importedRecordCount"] == 0
    assert rep["skippedRecordCount"] == 1
    assert rep["duplicateSignIds"] == [f"{CAPTURE}-a"]


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


def test_patch_rejects_unknown_status_values():
    """未知の状態値は 400（審核队列・統計から静黙に漏れるのを防ぐ）。"""
    rid = client.get("/records", params={"q": f"{CAPTURE}-b"}).json()["items"][0]["id"]
    for payload in [{"_status": "bogus"}, {"_status": ""},
                    {"DataStatus": "bogus"}, {"DataStatus": ""}]:
        r = client.patch(f"/records/{rid}", json=payload)
        assert r.status_code == 400, payload
    # 既知値は従来どおり通る（needs_review は Console 専用の審核状態）。
    r = client.patch(f"/records/{rid}", json={"DataStatus": "needs_review"})
    assert r.status_code == 200, r.text
    assert r.json()["DataStatus"] == "needs_review"


def test_legacy_phase0_endpoints_removed():
    """旧 /extract・/ai・/export・/export_bundle は Step 14 で削除済み。"""
    assert client.post("/extract").status_code in (404, 405)
    assert client.post("/ai").status_code in (404, 405)
    assert client.post("/export", json=[]).status_code in (404, 405)
    assert client.post("/export_bundle", json=[]).status_code in (404, 405)
    # 残すべき入口は生きている
    assert client.get("/ai/status").status_code == 200
    assert client.get("/schema").status_code == 200


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
    assert s["datasetCount"] == 2  # 指紋の異なる包の導入で dataset 行が増えた
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


# ── Step 15: 存储モデル（临时化・去重・清掃） ──


def test_import_leaves_no_tmp_or_imports():
    """新導入フローは tmp/ を掃除し、imports/ に何も残さない。"""
    from app.database import data_dir, tmp_dir
    assert list(tmp_dir().iterdir()) == []
    assert not (data_dir() / "imports").exists() or \
        list((data_dir() / "imports").iterdir()) == []


def test_fill_missing_restores_deleted_photo():
    """重複包の fill_missing: 正式庫から消えた写真を包から復元する。"""
    from app.database import photos_dir
    target = photos_dir() / f"{CAPTURE}-b.jpg"
    assert target.exists()
    target.unlink()  # 事故で消えた想定
    r = client.post(
        "/datasets/import",
        files={"file": ("llmap_dataset_test.zip", default_package(),
                        "application/zip")},
        data={"mode": "fill_missing"},
    )
    assert r.status_code == 200, r.text
    rep = r.json()
    assert rep["status"] == "filled"
    assert rep["restoredPhotoCount"] == 1
    assert target.exists()
    # 復元後は写真配信も生き返る
    rid = client.get("/records", params={"q": f"{CAPTURE}-b"}).json()["items"][0]["id"]
    assert client.get(f"/records/{rid}/photo").status_code == 200


def test_same_name_different_content_gets_renamed():
    """同名別内容の写真は既存を壊さず安全な別名で保存し、記録の参照も追随する。"""
    other = b"\xff\xd8\xff\xe0" + b"different-bytes" * 12 + b"\xff\xd9"
    cap = "OOK-9Zz1Aa2B-260702090000111"
    rows = [
        _row(SignID=f"{cap}-a", _status="pending", CaptureID=cap,
             地区コード="OOK", 採集日時="2026-07-02 09:00:00",
             主要言語="日本語",
             写真ファイル名=f"{CAPTURE}-a.jpg"),  # 既存名と衝突・内容は別
    ]
    files = {f"photos/{CAPTURE}-a.jpg": other}
    entries = [(f"photos/{CAPTURE}-a.jpg", f"{cap}-a", cap)]
    r = _import(make_package(rows, files, entries))
    assert r.status_code == 200, r.text
    rep = r.json()
    assert rep["status"] == "imported"
    assert rep["importedRecordCount"] == 1
    # 既存ファイルは無傷
    from app.database import photos_dir
    assert (photos_dir() / f"{CAPTURE}-a.jpg").read_bytes() == JPEG
    # 新記録は改名後のファイルを参照し、配信できる
    item = client.get("/records", params={"q": f"{cap}-a"}).json()["items"][0]
    assert item["写真ファイル名"] == f"{CAPTURE}-a~2.jpg"
    assert (photos_dir() / f"{CAPTURE}-a~2.jpg").read_bytes() == other
    assert client.get(f"/records/{item['id']}/photo").status_code == 200


def test_same_content_reused_not_duplicated():
    """同名同内容の写真は再保存しない（内容去重）。"""
    cap = "OOK-3Cc4Dd5E-260703100000222"
    rows = [
        _row(SignID=f"{cap}-a", _status="pending", CaptureID=cap,
             地区コード="OOK", 採集日時="2026-07-03 10:00:00",
             写真ファイル名=f"{CAPTURE}-a.jpg"),  # 既存名・同内容
    ]
    files = {f"photos/{CAPTURE}-a.jpg": JPEG}
    entries = [(f"photos/{CAPTURE}-a.jpg", f"{cap}-a", cap)]
    r = _import(make_package(rows, files, entries))
    rep = r.json()
    assert rep["status"] == "imported"
    assert rep["reusedPhotoCount"] == 1
    item = client.get("/records", params={"q": f"{cap}-a"}).json()["items"][0]
    assert item["写真ファイル名"] == f"{CAPTURE}-a.jpg"  # 改名なしで共用


def test_storage_summary_and_cleanup():
    from app.database import data_dir
    # 旧フローの遺留を模擬（imports/ に zip と展開目录）
    imports = data_dir() / "imports"
    imports.mkdir(exist_ok=True)
    (imports / "old_package.zip").write_bytes(b"x" * 2048)
    legacy_dir = imports / "old_package"
    legacy_dir.mkdir(exist_ok=True)
    (legacy_dir / "data.csv").write_text("SignID\n", encoding="utf-8")

    s = client.get("/storage/summary").json()
    assert s["dataDir"]
    assert s["categories"]["photos"] > 0
    assert s["reclaimableBytes"] > 2000
    assert "old_package.zip" in s["reclaimableEntries"]

    # dryRun（既定）は削除しない
    r = client.post("/storage/cleanup", json={"dryRun": True}).json()
    assert r["ok"] is True and r["deleted"] == 0
    assert (imports / "old_package.zip").exists()

    # 実削除
    r = client.post("/storage/cleanup", json={"dryRun": False}).json()
    assert r["ok"] is True and r["deleted"] >= 2
    assert not (imports / "old_package.zip").exists()
    assert not legacy_dir.exists()
    # 正式資産は無傷
    from app.database import photos_dir
    assert (photos_dir() / f"{CAPTURE}-a.jpg").exists()


def test_cleanup_refuses_when_official_photos_missing():
    """正式庫に欠落があるうちは清掃を拒否する（imports が復旧源かもしれない）。"""
    from app.database import data_dir, photos_dir
    imports = data_dir() / "imports"
    imports.mkdir(exist_ok=True)
    (imports / "maybe_needed.zip").write_bytes(b"y" * 100)
    target = photos_dir() / f"{CAPTURE}-a.jpg"
    backup = target.read_bytes()
    target.unlink()
    try:
        r = client.post("/storage/cleanup", json={"dryRun": False}).json()
        assert r["ok"] is False
        assert r["missingPhotoCount"] >= 1
        assert (imports / "maybe_needed.zip").exists()  # 削除されない
    finally:
        target.write_bytes(backup)
        (imports / "maybe_needed.zip").unlink()


# ── Step 16: 導出（GeoJSON / Dataset Package / 写真 ZIP） ──


def _wait_job(job_id: str, timeout: float = 15.0) -> dict:
    import time
    t0 = time.time()
    while time.time() - t0 < timeout:
        st = client.get(f"/export/jobs/{job_id}").json()
        if st["status"] != "running":
            return st
        time.sleep(0.05)
    raise AssertionError("export job timed out")


def test_export_geojson():
    r = client.get("/export/geojson")
    assert r.status_code == 200
    gj = r.json()
    assert gj["type"] == "FeatureCollection"
    assert gj["llmap"]["featureCount"] == len(gj["features"])
    assert gj["llmap"]["skippedNoGps"] >= 1  # GPS 無しは無音で捨てない
    f = [x for x in gj["features"]
         if x["properties"]["SignID"] == f"{CAPTURE}-a"][0]
    # RFC 7946: [経度, 緯度] の順
    assert f["geometry"]["coordinates"] == [139.7011, 35.6021]
    assert f["properties"]["主要言語"] == "英語"  # PATCH 済みの値
    assert f["properties"]["photo"] == f"photos/{CAPTURE}-a.jpg"
    # full props は CSV 全字段
    full = client.get("/export/geojson", params={"props": "full"}).json()
    fprops = [x for x in full["features"]
              if x["properties"]["SignID"] == f"{CAPTURE}-a"][0]["properties"]
    assert "備考" in fprops and "SchemaVersion" in fprops


def test_export_package_roundtrip():
    """Dataset Package 導出 → そのまま導入できる（往返互換）。"""
    r = client.post("/export/package", json={})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done", job
    assert job["fileName"].startswith("llmap_dataset_")
    assert job["report"]["recordCount"] >= 3
    dl = client.get(f"/export/jobs/{job['id']}/download")
    assert dl.status_code == 200

    zf = zipfile.ZipFile(io.BytesIO(dl.content))
    names = set(zf.namelist())
    for required in ["data.csv", "metadata.json", "schema.json",
                     "manifest.json", "MANIFEST.txt", "README.md"]:
        assert required in names, required
    manifest = json.loads(zf.read("manifest.json"))
    assert all(e["sha256"] and e["sizeBytes"] > 0 for e in manifest["files"])
    # 欠落（LEGACY crop）は missingFiles に明示される
    assert any(LEGACY_CAPTURE in e["path"] for e in manifest["missingFiles"])

    # 同じ DB に再導入 → 全行 SignID 重複で skip（data.csv が本物の証明）
    r2 = client.post(
        "/datasets/import",
        files={"file": (job["fileName"], dl.content, "application/zip")},
    )
    rep = r2.json()
    assert rep["status"] == "imported"
    assert rep["importedRecordCount"] == 0
    assert rep["skippedRecordCount"] == rep["recordCount"]


def test_export_package_respects_filters():
    r = client.post("/export/package", json={"entryMode": "quick"})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done"
    dl = client.get(f"/export/jobs/{job['id']}/download")
    zf = zipfile.ZipFile(io.BytesIO(dl.content))
    rows = list(csv.DictReader(
        io.StringIO(zf.read("data.csv").decode("utf-8-sig"))))
    assert len(rows) == 1
    assert rows[0]["EntryMode"] == "quick"


def test_export_photos_zip_dedup_and_mapping():
    """写真 ZIP: SignID 命名・photo_mapping.csv・内容ハッシュ去重。"""
    r = client.post("/export/photos",
                    json={"content": "both", "naming": "signid"})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done", job
    dl = client.get(f"/export/jobs/{job['id']}/download")
    zf = zipfile.ZipFile(io.BytesIO(dl.content))
    names = zf.namelist()
    assert "photo_mapping.csv" in names
    # テストの写真はすべて同一バイト列 → 内容去重で実体は 1 つだけ
    photo_files = [n for n in names if n.endswith(".jpg")]
    # 同一バイト列の写真（a/b/source の 3 つ）は 1 実体に去重され、
    # 別内容の写真（rename テストで導入した 1 枚）は別実体のまま。
    assert len(photo_files) == 2
    assert job["report"]["dedupedFiles"] >= 2
    rows = list(csv.DictReader(
        io.StringIO(zf.read("photo_mapping.csv").decode("utf-8-sig"))))
    by_id = {r["SignID"]: r for r in rows}
    shared = by_id[f"{CAPTURE}-a"]["照片文件"]
    assert shared in photo_files
    assert by_id[f"{CAPTURE}-b"]["照片文件"] == shared  # 同内容 → 同一実体
    assert by_id[f"{CAPTURE}-a"]["原图文件"] == shared  # source も同内容
    assert "MISSING.txt" in names


def test_export_job_not_found_and_cancel():
    assert client.get("/export/jobs/nonexistent").status_code == 404
    r = client.post("/export/photos", json={"content": "crop",
                                            "naming": "original"})
    job_id = r.json()["jobId"]
    _wait_job(job_id)
    assert client.post(f"/export/jobs/{job_id}/cancel").json()["ok"] is True
