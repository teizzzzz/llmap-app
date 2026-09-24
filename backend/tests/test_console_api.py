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
             補助言語="英語/タイ語", 担体類型="贴纸", 時間性="常设",
             EntryMode="standard", DataStatus="submitted",
             SchemaVersion="1.5", AppVersion="v1.8.0"),
        _row(SignID=f"{CAPTURE}-b", _status="pending", CaptureID=CAPTURE,
             DisplayID="OOK-20260701-008-b", 採集者ID="7Kx9Qp2A",
             地区コード="OOK", CropSuffix="b",
             写真ファイル名=f"{CAPTURE}-b.jpg",
             元写真ファイル名=f"{CAPTURE}-source.jpg",
             採集日時="2026-07-01 14:35:12", 主要言語="日本語",
             担体類型="无媒介",
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


def test_records_field_filters():
    """研究字段（字段表の字段）での筛选。fields は JSON で渡す。"""
    def p(f):
        return {"fields": json.dumps(f, ensure_ascii=False)}
    assert client.get("/records", params=p({"担体類型": "贴纸"})).json()["total"] == 1
    assert client.get("/records", params=p({"担体類型": "无媒介"})).json()["total"] == 1
    # 複合条件は AND
    assert client.get(
        "/records", params=p({"担体類型": "贴纸", "時間性": "常设"})).json()["total"] == 1
    assert client.get(
        "/records", params=p({"担体類型": "无媒介", "時間性": "常设"})).json()["total"] == 0
    # 同一字段の複数値は OR
    assert client.get(
        "/records", params=p({"担体類型": ["贴纸", "无媒介"]})).json()["total"] == 2
    # 複数選択字段（主要言語 "韓国語/日本語"）は含有判定
    assert client.get("/records", params=p({"主要言語": "韓国語"})).json()["total"] == 1
    # 系統字段・未知字段・壊れた JSON は 400
    # （黙って条件を落とすと「筛选したつもりで全件導出」になるため）
    assert client.get("/records", params=p({"SignID": "x"})).status_code == 400
    assert client.get("/records", params=p({"未知字段": "x"})).status_code == 400
    assert client.get("/records", params={"fields": "not-json"}).status_code == 400
    # CSV 導出にも同じ筛选が効く
    r = client.get("/export/csv", params=p({"担体類型": "贴纸"}))
    rows = list(csv.DictReader(io.StringIO(r.content.decode("utf-8-sig"))))
    assert [row["SignID"] for row in rows] == [f"{CAPTURE}-a"]


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
    # キー未設定の初期状態: disabled・プロバイダ空・案内メッセージ。
    s = client.get("/ai/status").json()
    assert s["enabled"] is False
    assert s["providers"] == []
    assert "未設定" in s["message"]


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


def test_photo_thumbnails():
    """縮略図: 実 JPEG は長辺 512px に縮小、開けないファイルは原図へ
    フォールバック。一覧の thumbnailUrl は /thumb を指す。"""
    from pathlib import Path

    from PIL import Image

    # 一覧の thumbnailUrl が縮略図端点になっている
    item = client.get("/records", params={"q": f"{CAPTURE}-a"}).json()["items"][0]
    assert item["thumbnailUrl"] == f"/records/{item['id']}/thumb"

    # フォールバック: テストの偽 JPEG は Pillow で開けない → 原図をそのまま返す
    r = client.get(f"/records/{item['id']}/thumb")
    assert r.status_code == 200
    assert r.content == JPEG

    # 実 JPEG: 2000px の画像を photos/ に置くと 512px に縮小される
    photos = Path(os.environ["LLMAP_DATA_DIR"]) / "photos"
    big = photos / "thumbtest-big.jpg"
    Image.new("RGB", (2000, 1000), (200, 50, 50)).save(big, "JPEG")
    r = client.get("/thumbs/thumbtest-big.jpg")
    assert r.status_code == 200
    with Image.open(io.BytesIO(r.content)) as im:
        assert max(im.size) == 512
    # キャッシュが生成されている
    assert (Path(os.environ["LLMAP_DATA_DIR"]) / "thumbs"
            / "512_thumbtest-big.jpg").is_file()
    # 目录穿越は拒否
    assert client.get("/thumbs/..%2Fsecret.jpg").status_code in (400, 404)


def test_stats_fields_presence():
    """研究字段の非空記録数（筛选 UI が空字段を隠すために使う）。"""
    r = client.get("/stats/fields")
    assert r.status_code == 200
    body = r.json()
    assert body["担体類型"] == 2       # seed の a/b に値あり
    assert body["主要言語"] >= 3       # ほぼ全記録に値あり（他テストの追加分に依存しない）
    assert body["空間階層"] == 0       # 全記録空 → UI で隠れる
    assert "SignID" not in body        # 系統字段は対象外


def test_export_photos_preview_respects_filters():
    """写真 ZIP の事前集計は筛选条件に従う（全件になっていないこと）。"""
    # 全件 = /records の total と一致（他テストが追加した記録も含む）
    total = client.get(
        "/records", params={"page": 1, "pageSize": 1}).json()["total"]
    all_ = client.post("/export/photos/preview", json={}).json()
    assert all_["recordCount"] == total
    assert all_["missingCount"] >= 1   # LEGACY crop 欠落
    # 字段筛选（担体類型=贴纸 → 記録 a のみ）
    one = client.post(
        "/export/photos/preview",
        json={"fields": {"担体類型": "贴纸"}, "content": "both"}).json()
    assert one["recordCount"] == 1
    assert one["cropFiles"] == 1
    assert one["sourceFiles"] == 1
    assert one["totalFiles"] == 2
    # crop のみ
    crop = client.post(
        "/export/photos/preview",
        json={"fields": {"担体類型": "贴纸"}, "content": "crop"}).json()
    assert crop["totalFiles"] == 1 and crop["sourceFiles"] == 0
    assert client.post("/export/photos/preview",
                       json={"content": "bogus"}).status_code == 400


def test_export_photos_output_dir():
    """outputDir 指定: zip がその目录に生成される（設定は変更しない）。"""
    from pathlib import Path

    custom = Path(os.environ["LLMAP_DATA_DIR"]) / "oneshot_exports"
    r = client.post("/export/photos", json={
        "content": "crop", "naming": "original", "outputDir": str(custom)})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done", job
    assert Path(job["path"]).parent == custom
    assert Path(job["path"]).is_file()
    # 相対パスは 400（ジョブ開始前に弾く）
    assert client.post("/export/photos", json={
        "content": "crop", "outputDir": "relative/dir"}).status_code == 400
    # 設定の exportDir は変わっていない
    assert client.get("/config").json()["exportDir"] is None


def test_export_photos_split_by_field():
    """字段別分包: 各値ごとに <字段slug>_<値slug>.zip、筛选にも従う。"""
    from pathlib import Path

    custom = Path(os.environ["LLMAP_DATA_DIR"]) / "split_exports"
    r = client.post("/export/photos/split", json={
        "field": "担体類型", "content": "crop", "naming": "original",
        "outputDir": str(custom)})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done", job
    # seed: 貼紙(a)・无媒介(b) の 2 値のみ値あり → carrier_sticker / carrier_nomedium
    assert job["report"]["zipCount"] == 2
    assert (custom / "carrier_sticker.zip").is_file()
    assert (custom / "carrier_nomedium.zip").is_file()
    zf = zipfile.ZipFile(custom / "carrier_sticker.zip")
    rows = list(csv.DictReader(
        io.StringIO(zf.read("photo_mapping.csv").decode("utf-8-sig"))))
    assert [row["SignID"] for row in rows] == [f"{CAPTURE}-a"]
    # 分包ジョブの単一下载は不可（個別 zip は目录に生成済み）
    assert client.get(f"/export/jobs/{job['id']}/download").status_code == 409
    # 枚挙字段以外は 400
    assert client.post("/export/photos/split",
                       json={"field": "備考"}).status_code == 400
    assert client.post("/export/photos/split",
                       json={"field": ""}).status_code == 400

    # 言語字段: 枚挙外の小語種（タイ語）は「その他」桶 = sub_other へ。
    # 複数選択（英語/タイ語）は両方の zip に入る。
    custom2 = Path(os.environ["LLMAP_DATA_DIR"]) / "split_exports_sub"
    r = client.post("/export/photos/split", json={
        "field": "補助言語", "content": "crop", "naming": "original",
        "outputDir": str(custom2)})
    job = _wait_job(r.json()["jobId"])
    assert job["status"] == "done", job
    assert (custom2 / "sub_en.zip").is_file()
    assert (custom2 / "sub_other.zip").is_file()
    assert not (custom2 / "sub_jp.zip").exists()  # 補助言語に日本語は無い


def test_export_job_not_found_and_cancel():
    assert client.get("/export/jobs/nonexistent").status_code == 404
    r = client.post("/export/photos", json={"content": "crop",
                                            "naming": "original"})
    job_id = r.json()["jobId"]
    _wait_job(job_id)
    assert client.post(f"/export/jobs/{job_id}/cancel").json()["ok"] is True


def test_config_export_dir_roundtrip():
    """導出目录設定: 設定 → 導出がその目录に生成 → リセットで既定へ戻る。"""
    from pathlib import Path

    # 既定状態
    cfg = client.get("/config").json()
    assert cfg["exportDir"] is None
    default_dir = cfg["defaultExportDir"]
    assert cfg["effectiveExportDir"] == default_dir

    custom = Path(os.environ["LLMAP_DATA_DIR"]) / "custom_exports"
    try:
        # 設定（絶対パス・自動作成・書き込み検証）
        r = client.put("/config", json={"exportDir": str(custom)})
        assert r.status_code == 200, r.text
        assert r.json()["effectiveExportDir"] == str(custom)
        assert custom.is_dir()

        # 導出ジョブがその目录に生成される（job.path でフルパスも返る）
        job = _wait_job(client.post("/export/package", json={}).json()["jobId"])
        assert job["status"] == "done", job
        assert job["path"].startswith(str(custom))
        assert (custom / job["fileName"]).is_file()
        # ダウンロードも従来どおり動く
        assert client.get(f"/export/jobs/{job['id']}/download").status_code == 200

        # 検証エラー: 相対パスは 400・設定は変わらない
        assert client.put("/config", json={"exportDir": "relative/dir"}).status_code == 400
        assert client.get("/config").json()["effectiveExportDir"] == str(custom)
        # 未知キーは 400
        assert client.put("/config", json={"bogus": 1}).status_code == 400
    finally:
        # リセット（他テストの exports 期待に影響させない）
        r = client.put("/config", json={"exportDir": None})
        assert r.json()["exportDir"] is None
        assert r.json()["effectiveExportDir"] == default_dir


# ── Step 18: バッチ AI（v6 併合規則・設定・ジョブ） ──


def test_merge_ai_draft_rules():
    """record_ops.dart mergeAiDraft と同一の併合規則（移植の単体検証）。"""
    from app.ai_engine import merge_ai_draft
    from app.schema import MULTI_FIELDS

    multi = set(MULTI_FIELDS)

    # 備考: 追記のみ（例: 备注「复数」+ AI「123」→「复数 123」）
    data = {"備考": "复数"}
    assert merge_ai_draft(data, {"備考": "123"}, multi) == 1
    assert data["備考"] == "复数 123"
    # 同文の重複追記はしない / 「—」は書かない
    assert merge_ai_draft(data, {"備考": "123"}, multi) == 0
    assert merge_ai_draft(data, {"備考": "—"}, multi) == 0
    assert data["備考"] == "复数 123"

    # 複数選択: 和集合（既存を保ち新値のみ後ろへ）
    data = {"主要言語": "日本語"}
    assert merge_ai_draft(data, {"主要言語": "日本語/英語"}, multi) == 1
    assert data["主要言語"] == "日本語/英語"
    # 既存「—」（明示的な無し）は人の判断 — 上書きしない
    data = {"補助言語": "—"}
    assert merge_ai_draft(data, {"補助言語": "英語"}, multi) == 0
    assert data["補助言語"] == "—"

    # 単一選択: 空欄のみ埋める
    data = {"時間性": "常设", "可読性": ""}
    n = merge_ai_draft(data, {"時間性": "一过性", "可読性": "完全可读"}, multi)
    assert n == 1
    assert data["時間性"] == "常设"       # 既存は不変
    assert data["可読性"] == "完全可读"   # 空欄は埋まる

    # 規則2: 空値・null は一切書かない
    data = {"文字性": ""}
    assert merge_ai_draft(data, {"文字性": "", "製作品質": None}, multi) == 0
    assert data["文字性"] == ""


def test_ai_config_keys_and_status():
    """AI キー設定: PUT で保存・GET は完全なキーを返さない（ヒントのみ）。"""
    try:
        r = client.put("/config", json={
            "aiProvider": "claude", "claudeApiKey": "sk-ant-test-12345678"})
        assert r.status_code == 200, r.text
        cfg = r.json()
        assert cfg["aiProvider"] == "claude"
        assert cfg["claudeApiKeySet"] is True
        assert cfg["claudeApiKeyHint"] == "…5678"
        # CORS 全開のため GET 応答に生キーを含めない
        assert "sk-ant-test-12345678" not in json.dumps(cfg)

        s = client.get("/ai/status").json()
        assert s["enabled"] is True
        assert s["provider"] == "claude"
        assert s["providers"] == ["claude"]

        # 不正プロバイダは 400
        assert client.put("/config", json={"aiProvider": "gpt"}).status_code == 400
    finally:
        r = client.put("/config", json={"aiProvider": None, "claudeApiKey": None})
        assert r.json()["claudeApiKeySet"] is False
    assert client.get("/ai/status").json()["enabled"] is False


def test_ai_preview_counts():
    p = client.post("/ai/preview", json={}).json()
    assert p["total"] >= 3
    assert p["withPhoto"] >= 2
    assert p["total"] == p["withPhoto"] + p["withoutPhoto"] + p["missingPhotoFile"]
    assert isinstance(p["byStatus"], dict) and p["byStatus"]


def _wait_ai_job(job_id: str, timeout: float = 15.0) -> dict:
    import time
    t0 = time.time()
    while time.time() - t0 < timeout:
        st = client.get(f"/ai/jobs/{job_id}").json()
        if st["status"] != "running":
            return st
        time.sleep(0.05)
    raise AssertionError("ai job timed out")


def test_ai_batch_job_merges_and_promotes(monkeypatch):
    """バッチ AI: 下書き併合・pending→ai 昇格・再実行は冪等（二重追記しない）。"""
    from app import ai_engine

    draft = {
        "文字性": "文字",
        "主要言語": "日本語/英語",   # 既存「日本語」との和集合 → 英語のみ追加
        "時間性": "常设",
        "備考": "【判断】テスト観察",
        "可読性": "",                # 不確実 → 書かない
        "名称": "混入テスト",        # AI 対象外 → 落とされる
    }
    monkeypatch.setattr(
        ai_engine, "judge_photo",
        lambda provider, path, fields, key, model="": dict(draft))
    client.put("/config", json={"claudeApiKey": "sk-test-dummy"})
    try:
        target_q = f"{CAPTURE}-b"  # pending / 主要言語=日本語 / 写真あり
        r = client.post("/ai/jobs", json={"q": target_q})
        assert r.status_code == 200, r.text
        job = _wait_ai_job(r.json()["jobId"])
        assert job["status"] == "done", job
        assert job["provider"] == "claude"
        assert job["report"]["changedRecords"] == 1
        assert job["report"]["errorCount"] == 0

        item = client.get("/records", params={"q": target_q}).json()["items"][0]
        detail = client.get(f"/records/{item['id']}").json()
        d = detail["data"]
        assert d["文字性"] == "文字"
        assert d["主要言語"] == "日本語/英語"
        assert d["時間性"] == "常设"
        assert d["備考"] == "【判断】テスト観察"
        assert d.get("可読性", "") == ""          # 空値は書かれない
        assert d.get("名称", "") == ""            # AI 対象外は混入しない
        assert d["_status"] == "ai"               # pending → ai 昇格
        assert d["DataStatus"] == "ai_drafted"

        # 再実行 → 併合規則が守るので何も変わらない（備考の二重追記なし）
        job2 = _wait_ai_job(
            client.post("/ai/jobs", json={"q": target_q}).json()["jobId"])
        assert job2["report"]["changedRecords"] == 0
        assert job2["report"]["unchangedRecords"] == 1
        d2 = client.get(f"/records/{item['id']}").json()["data"]
        assert d2["備考"] == "【判断】テスト観察"
        assert d2["_status"] == "ai"

        # human-reviewed は昇格も降格もしない（併合だけ行われる）
        legacy_q = f"{LEGACY_CAPTURE}-a"
        job3 = _wait_ai_job(
            client.post("/ai/jobs", json={"q": legacy_q}).json()["jobId"])
        assert job3["status"] == "done", job3
        litem = client.get("/records", params={"q": legacy_q}).json()["items"][0]
        ld = client.get(f"/records/{litem['id']}").json()["data"]
        assert ld["_status"] == "human-reviewed"
    finally:
        client.put("/config", json={"claudeApiKey": None})


def test_ai_batch_aborts_after_consecutive_failures(monkeypatch):
    """キー無効等の連続失敗は 3 件で中止（全件を空振りしない）。"""
    from app import ai_engine

    def boom(provider, path, fields, key, model=""):
        raise RuntimeError("Claude API 401: invalid x-api-key")

    monkeypatch.setattr(ai_engine, "judge_photo", boom)
    client.put("/config", json={"claudeApiKey": "sk-test-bad"})
    try:
        job = _wait_ai_job(client.post("/ai/jobs", json={}).json()["jobId"])
        assert job["status"] == "error"
        assert "中止" in job["error"]
        assert 1 <= len(job["errors"]) <= 20
    finally:
        client.put("/config", json={"claudeApiKey": None})


def test_ai_job_requires_key_and_validates_provider():
    assert client.post("/ai/jobs", json={}).status_code == 400
    client.put("/config", json={"claudeApiKey": "sk-test-dummy"})
    try:
        assert client.post(
            "/ai/jobs", json={"provider": "gpt"}).status_code == 400
    finally:
        client.put("/config", json={"claudeApiKey": None})


def test_ai_model_selection(monkeypatch):
    """モデル選択: 設定往復・不正値 400・ジョブが選択モデルで走る。"""
    from app import ai_engine

    # 既定: 選択肢の先頭（Haiku / Flash）
    cfg = client.get("/config").json()
    assert cfg["claudeModel"] == ai_engine.CLAUDE_MODELS[0]
    assert cfg["geminiModel"] == ai_engine.GEMINI_MODELS[0]
    s = client.get("/ai/status").json()
    assert s["models"]["claude"] == ai_engine.CLAUDE_MODELS[0]
    assert s["modelOptions"]["claude"] == list(ai_engine.CLAUDE_MODELS)

    seen = {}

    def fake(provider, path, fields, key, model=""):
        seen["model"] = model
        return {"文字性": ""}  # 何も書かない下書き

    monkeypatch.setattr(ai_engine, "judge_photo", fake)
    try:
        # モデルを Sonnet 5 に切替
        r = client.put("/config", json={
            "claudeApiKey": "sk-test-dummy", "claudeModel": "claude-sonnet-5"})
        assert r.status_code == 200, r.text
        assert r.json()["claudeModel"] == "claude-sonnet-5"
        assert client.get("/ai/status").json()["models"]["claude"] == "claude-sonnet-5"

        # 不正モデルは 400・設定は不変
        assert client.put(
            "/config", json={"claudeModel": "gpt-5"}).status_code == 400
        assert client.get("/config").json()["claudeModel"] == "claude-sonnet-5"

        # ジョブは選択モデルで実行され、状態にも載る
        job = _wait_ai_job(client.post(
            "/ai/jobs", json={"q": f"{CAPTURE}-b"}).json()["jobId"])
        assert job["status"] == "done", job
        assert job["model"] == "claude-sonnet-5"
        assert seen["model"] == "claude-sonnet-5"

        # null で既定へ戻る
        assert client.put("/config", json={"claudeModel": None}) \
            .json()["claudeModel"] == ai_engine.CLAUDE_MODELS[0]
    finally:
        client.put("/config", json={"claudeApiKey": None, "claudeModel": None})


def test_ai_job_realtime_logs(monkeypatch):
    """実時ログ: jobStart→レコード結果→done、afterSeq の増分取得。"""
    from app import ai_engine

    monkeypatch.setattr(
        ai_engine, "judge_photo",
        lambda provider, path, fields, key, model="": {"備考": "【判断】log-test"})
    client.put("/config", json={"claudeApiKey": "sk-test-dummy"})
    try:
        jid = client.post("/ai/jobs", json={"q": CAPTURE}).json()["jobId"]
        st = _wait_ai_job(jid)
        assert st["status"] == "done", st

        logs = st["logs"]
        assert logs[0]["event"] == "jobStart"
        assert logs[0]["data"]["total"] == st["report"]["recordCount"]
        assert logs[-1]["event"] == "done"
        assert st["lastSeq"] == logs[-1]["seq"]
        # レコード 1 件につき結果ログが 1 行
        outcomes = [e for e in logs
                    if e["event"] in ("changed", "unchanged", "skipped", "error")]
        assert len(outcomes) == st["report"]["recordCount"]
        assert all(e["signId"] for e in outcomes)

        # 増分取得: 先頭行の seq を afterSeq に渡すと 2 行目から返る
        part = client.get(f"/ai/jobs/{jid}",
                          params={"afterSeq": logs[0]["seq"]}).json()
        assert part["logs"][0]["seq"] == logs[1]["seq"]
        # 最終 seq 以降は空
        empty = client.get(f"/ai/jobs/{jid}",
                           params={"afterSeq": st["lastSeq"]}).json()
        assert empty["logs"] == []
    finally:
        client.put("/config", json={"claudeApiKey": None})


def test_schema_exposes_system_fields():
    """Console の研究字段派生（表頭 − 系統字段）の材料が /schema に載る。"""
    s = client.get("/schema").json()
    assert "_status" in s["system_fields"]
    assert "DataStatus" in s["system_fields"]
    research = [f for f in s["csv_header"] if f not in s["system_fields"]]
    # v6 の 13 AI 維度＋人力字段が全て導出できる（UI 側の隠し分は Console の責務）
    for f in ("文字性", "装飾の言語", "放置位置", "時間性", "可読性",
              "重ね書き", "ディスコース類型", "製作品質", "備考"):
        assert f in research, f


# ── データセット多选（導出の複数データセット選択） ──

MSA_CAPTURE = "OOK-multiA-260702100000000"
MSB_CAPTURE = "OOK-multiB-260702110000000"


def _mini_package(capture: str, lang: str) -> bytes:
    """1 記録だけの最小パッケージ（写真なし・GPS あり）。"""
    rows = [_row(SignID=f"{capture}-a", _status="pending", CaptureID=capture,
                 DisplayID=f"{capture}-a", 採集者ID="multi",
                 地区コード="OOK", CropSuffix="a",
                 緯度="35.6030", 経度="139.7020",
                 採集日時="2026-07-02 10:00:00", 主要言語=lang,
                 EntryMode="quick", DataStatus="raw",
                 SchemaVersion="1.5", AppVersion="v1.12.5")]
    return make_package(rows, {}, [])


def test_dataset_multiselect_filters():
    """datasetIds（"1,3" / JSON 配列）で複数データセットをまとめて筛选・導出。"""
    ra = _import(_mini_package(MSA_CAPTURE, "日本語")).json()
    rb = _import(_mini_package(MSB_CAPTURE, "英語")).json()
    assert ra["status"] == "imported" and rb["status"] == "imported"
    ida, idb = ra["datasetId"], rb["datasetId"]

    # GET /records: カンマ区切りの複数値
    assert client.get(
        "/records", params={"datasetIds": f"{ida},{idb}"}).json()["total"] == 2
    only_a = client.get("/records", params={"datasetIds": str(ida)}).json()
    assert only_a["total"] == 1
    assert only_a["items"][0]["SignID"] == f"{MSA_CAPTURE}-a"
    # 後方互換: 単値 datasetId は従来どおり
    assert client.get("/records", params={"datasetId": idb}).json()["total"] == 1
    # 不正値の混入は無視される（"abc" だけなら未指定扱い）
    assert client.get(
        "/records", params={"datasetIds": f"{ida},abc"}).json()["total"] == 1

    # CSV 導出も同じ多选筛选を通る
    csv_text = client.get(
        "/export/csv", params={"datasetIds": f"{ida},{idb}"}).text
    assert f"{MSA_CAPTURE}-a" in csv_text
    assert f"{MSB_CAPTURE}-a" in csv_text

    # GeoJSON 導出
    geo = json.loads(client.get(
        "/export/geojson", params={"datasetIds": f"{ida},{idb}"}).text)
    assert geo["llmap"]["featureCount"] == 2

    # POST 系（導出ジョブ / AI と共通の _filters_kwargs）: JSON 配列を受ける
    assert client.post(
        "/ai/preview", json={"datasetIds": [ida, idb]}).json()["total"] == 2
    assert client.post(
        "/ai/preview", json={"datasetIds": [ida]}).json()["total"] == 1

    # 地図 API も多选可
    assert len(client.get(
        "/map/records", params={"datasetIds": f"{ida},{idb}"}).json()) == 2


def test_storage_reset_wipes_everything_but_settings():
    """全データ削除（初期化）: confirm 必須／記録・写真・遺留を全消し／settings 保持。
    ※ 全データを消すため、このテストは必ずファイル末尾（最後）に置くこと。"""
    from app.database import (
        data_dir, load_settings, photos_dir, save_settings, source_photos_dir,
    )

    before = client.get("/records").json()["total"]
    assert before > 0

    # 誤操作防止: confirm 無し / 不一致は 400 で何も起きない
    assert client.post("/storage/reset", json={}).status_code == 400
    assert client.post(
        "/storage/reset", json={"confirm": "delete"}).status_code == 400
    assert client.get("/records").json()["total"] == before

    # settings.json（AI キー・導出先の置き場）は初期化後も残ること
    save_settings({"marker": "keep-me"})

    r = client.post("/storage/reset", json={"confirm": "DELETE"}).json()
    assert r["ok"] is True
    assert r["deletedRecords"] == before
    assert r["freedBytes"] > 0

    assert client.get("/records").json()["total"] == 0
    assert list(photos_dir().iterdir()) == []
    assert list(source_photos_dir().iterdir()) == []
    assert list((data_dir() / "imports").iterdir()) == []
    assert list((data_dir() / "archives").iterdir()) == []
    assert load_settings().get("marker") == "keep-me"
