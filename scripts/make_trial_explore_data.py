"""Web 試用版に同梱する「見本の探索データ」を作る。

起動中の backend（既定 http://127.0.0.1:8011）から記録を選び、探索バンドル
（data.js・atlas）と縮略図を、手機アプリの探索タブが読む形に並べて書き出す:

    <out>/data/data.js      window.LLV_DATA = {...}
    <out>/data/atlas.webp
    <out>/thumbs/<写真名>   長辺 512px の JPEG

使い方:
    python scripts/make_trial_explore_data.py <out_dir> [--api URL] [--count 300]

写真には通行人や店名が写ることがある。公開する前に <out>/thumbs を目で確認し、
出したくない写真は --exclude ids.txt（記録 id を 1 行ずつ）で外して作り直すこと。
"""
from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.request
from pathlib import Path


def call(api: str, path: str, payload=None, raw=False):
    req = urllib.request.Request(api + path)
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, data, timeout=120) as r:
        body = r.read()
    return body if raw else json.loads(body)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--api", default="http://127.0.0.1:8011")
    ap.add_argument("--count", type=int, default=300)
    ap.add_argument("--exclude", default="")
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    out = Path(a.out)
    exclude = set()
    if a.exclude:
        exclude = {int(x) for x in Path(a.exclude).read_text().split() if x.strip()}

    # 写真と位置のある記録を全部読む（言語が偏らないように選ぶため）。
    items, page = [], 1
    while True:
        r = call(a.api, f"/records?hasPhoto=true&hasGps=true&pageSize=500&page={page}")
        items += r["items"]
        if len(items) >= r["total"] or not r["items"]:
            break
        page += 1
    items = [x for x in items if x["id"] not in exclude]
    rng = random.Random(a.seed)
    # 日本語だけの記録が大半なので、他の言語を含む記録を先に全部入れ、残りを日本語から。
    other = [x for x in items if (x.get("主要言語") or "") not in ("日本語", "", "—")]
    ja = [x for x in items if x not in other]
    rng.shuffle(other)
    rng.shuffle(ja)
    n_other = min(len(other), a.count * 2 // 3)
    chosen = other[:n_other] + ja[: a.count - n_other]
    ids = sorted(x["id"] for x in chosen)
    print(f"selected {len(ids)} records ({n_other} with other languages)")

    job = call(a.api, "/explore/build", {"ids": ids})["jobId"]
    while True:
        st = call(a.api, f"/explore/jobs/{job}")
        if st["status"] != "running":
            break
        time.sleep(0.5)
    if st["status"] != "done" or not st["key"]:
        print("build failed:", st, file=sys.stderr)
        return 1
    key = st["key"]

    (out / "data").mkdir(parents=True, exist_ok=True)
    (out / "thumbs").mkdir(parents=True, exist_ok=True)
    js = call(a.api, f"/explore/bundles/{key}/data.js", raw=True).decode("utf-8")
    data = json.loads(js[len("window.LLV_DATA = "):-1])
    data["atlas"]["file"] = "data/atlas.webp"
    for rec in data["records"]:
        rec.pop("rid", None)   # 研究台の内部 id は公開データに入れない
        rec.pop("st", None)
    (out / "data" / "data.js").write_text(
        "window.LLV_DATA = " + json.dumps(data, ensure_ascii=False) + ";", encoding="utf-8")
    (out / "data" / "atlas.webp").write_bytes(
        call(a.api, f"/explore/bundles/{key}/atlas.webp", raw=True))
    total = 0
    for rec in data["records"]:
        name = rec["ph"]
        b = call(a.api, "/thumbs/" + urllib.request.quote(name), raw=True)
        (out / "thumbs" / name).write_bytes(b)
        total += len(b)
    print(f"wrote {len(data['records'])} records, thumbs {total / 1e6:.1f} MB -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
