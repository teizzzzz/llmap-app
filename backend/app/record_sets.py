"""記録集合（明確な記録の集合を範囲として使う）。

探索の主题・関連・色などの条件は研究の筛选（SQL）に直接置き換えられない。
その結果を「記録 id の集合」として登録し、key で筛选に使う（/records・
/map/records・審核・AI・導出・探索で共通）。条件を黙って落とさず、
同じ記録の集まりをどの画面でも扱えるようにするため。

- POST /record-sets {ids}   → {key, count}（同じ id 群なら同じ key）
- GET  /record-sets/{key}   → {key, ids}
key は id 群の sha1。data_dir/sets/<key>.json に保存するので backend を
再起動しても使える（小さな JSON。古いものは掃除しない —— 数 KB/件）。
"""
from __future__ import annotations

import hashlib
import json
import threading

from fastapi import APIRouter, Body, HTTPException

from .database import data_dir

router = APIRouter(tags=["record-sets"])

_CACHE: dict[str, list[int]] = {}
_LOCK = threading.Lock()
MAX_IDS = 100_000


def _dir():
    d = data_dir() / "sets"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _norm(ids) -> list[int]:
    out: set[int] = set()
    for x in ids or []:
        try:
            out.add(int(x))
        except (TypeError, ValueError):
            continue
    return sorted(out)


def set_key(ids: list[int]) -> str:
    return hashlib.sha1(",".join(map(str, ids)).encode()).hexdigest()[:16]


def register(ids) -> tuple[str, list[int]]:
    ids = _norm(ids)
    if len(ids) > MAX_IDS:
        raise HTTPException(400, f"集合が大きすぎます（{len(ids)} > {MAX_IDS}）")
    key = set_key(ids)
    with _LOCK:
        if key not in _CACHE:
            p = _dir() / f"{key}.json"
            if not p.is_file():
                p.write_text(json.dumps(ids), encoding="utf-8")
            _CACHE[key] = ids
    return key, ids


def resolve(key: str) -> list[int]:
    """key → id 群。不明な key は 404（黙って全件にしない）。"""
    if not key or not key.isalnum():
        raise HTTPException(400, f"不正な集合 key です: {key!r}")
    with _LOCK:
        ids = _CACHE.get(key)
        if ids is None:
            p = _dir() / f"{key}.json"
            if not p.is_file():
                raise HTTPException(404, f"記録集合が見つかりません: {key}")
            try:
                ids = _norm(json.loads(p.read_text(encoding="utf-8")))
            except (OSError, ValueError):
                raise HTTPException(404, f"記録集合が読めません: {key}")
            _CACHE[key] = ids
    return ids


@router.post("/record-sets")
def create_record_set(payload: dict = Body(...)):
    key, ids = register(payload.get("ids"))
    return {"key": key, "count": len(ids)}


@router.get("/record-sets/{key}")
def get_record_set(key: str):
    return {"key": key, "ids": resolve(key)}
