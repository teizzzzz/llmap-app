"""桌面の「探索」: 本地の資料庫から llmap-view と同じ形の探索データを作る。

llmap-view（静的サイト）の tools/build_demo_data.py を本地 DB 向けに移植したもの。
写真ごとの色の特徴（OKLab の調色板・色ヒストグラム・鮮やかさ）は一度だけ計算して
data_dir/explore/ にキャッシュし、範囲（全記録・資料庫の筛选・手動選択）ごとの
バンドル（data.js ＋ atlas.webp）はキャッシュから素早く組み立てる。

依存は numpy と Pillow のみ（scipy は使わない）:
  - k-means は numpy で実装（kmeans++ 初期化・固定 seed）。
  - 色轮・色相×明度の格子割当は llmap-view の最適割当（Hungarian）の代わりに
    「距離の短い順に空いている格子へ」の貪欲割当 —— 見た目はほぼ同じで、
    依存と打包サイズを増やさない。
地図座標 x/y は llmap-view の底図（新大久保の調査区域）と同じ線形投影
（llmap-view の 1933 件から最小二乗で求めた係数。誤差 0.05px）。"""
from __future__ import annotations

import hashlib
import io
import json
import math
import threading
import time
import uuid
from dataclasses import dataclass, field

import numpy as np
from fastapi import APIRouter, Body, HTTPException
from fastapi.responses import FileResponse, Response
from PIL import Image, ImageDraw
from sqlmodel import Session

from .database import data_dir, get_engine, photos_dir
from .db_models import SignRecord
from .export_jobs import _filters_kwargs, _load_records
from .schema import split_multi

router = APIRouter(tags=["explore"])

BUNDLE_VERSION = 1      # 形式を変えたら上げる（キャッシュの作り直し）
FEATURE_VERSION = 1
K = 5                   # 写真ごとの k-means の色数
MIN_PROP = 0.03         # これ未満の面積の色は調色板から外す
SAMPLE_PX = 96          # 色分析に使う縮小サイズ（長辺）
TILE = 64               # atlas の 1 枚（正方形・中央切り抜き）
ATLAS_COLS = 64
N_NEIGHBORS = 24
ACHROMA_C = 0.035       # OKLCH の彩度がこれ未満 = 無彩色

# 底図（llmap-view data/basemap.js）と同じ投影: x = a·lon + b, y = c·lat + d
PROJ_X = (268823.93907128606, -37553746.010927364)
PROJ_Y = (-331051.8930275165, 11819259.24034782)

# 言語の正準値（日本語名）→ llmap-view の言語コード。
LANG_CODES = {
    "日本語": "ja", "英語": "en", "中国語": "zh", "韓国語": "ko",
    "ベトナム語": "vi", "ネパール語": "ne", "タイ語": "th", "ヒンディー語": "hi",
    "アラビア語": "ar", "スペイン語": "es", "ミャンマー語": "my", "フランス語": "fr",
    "インドネシア語": "id", "ポーランド語": "pl", "ロシア語": "ru",
    "ウルドゥー語": "ur", "サンスクリット語": "sa", "その他": "other",
}
LANG_NAMES = {code: name for name, code in LANG_CODES.items()}

COLOR_NAMES = ["red", "orange", "yellow", "green", "blue", "purple", "pink",
               "brown", "white", "gray", "black"]

# 研究字段の短縮キー（llmap-view の f と同じ）と値の正規化（繁/日の字形 → 簡体）。
FIELDS = {"rel": "多言語関係", "car": "担体類型", "pos": "放置位置", "tmp": "時間性",
          "rd": "可読性", "dis": "ディスコース類型", "q": "製作品質"}
CHAR_MAP = str.maketrans({
    "訳": "译", "複": "复", "製": "制", "単": "单", "無": "无", "幟": "帜", "築": "筑",
    "設": "设", "過": "过", "読": "读", "話": "话", "語": "语", "業": "业", "規": "规",
    "約": "约", "際": "际", "礎": "础", "専": "专", "專": "专", "紙": "纸",
})
ALIASES = {
    "单言语型": "单语型", "单语型": "单语型",
    "商业": "商业话语", "规约": "规约性话语", "基础设施": "基础设施话语",
    "专门印刷": "专业印刷", "专門印刷": "专业印刷",
}


def norm_value(v: str) -> str:
    v = (v or "").strip()
    if v in ("", "—", "-"):
        return "未标注"
    v = v.split("/")[0].strip()
    v = v.translate(CHAR_MAP)
    return ALIASES.get(v, v)


def lang_codes(value: str) -> list[str]:
    out: list[str] = []
    for name in split_multi(value):
        if name == "不明":
            continue
        code = LANG_CODES.get(name, "other")
        if code not in out:
            out.append(code)
    return out


# ── 色の計算（llmap-view と同じ式） ─────────────────────────────────

def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    l_ = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m_ = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s_ = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    ], axis=-1)


def lch(lab) -> tuple[float, float, float]:
    L, a, b = (float(x) for x in lab)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def color_name(L: float, C: float, h: float) -> str:
    if C < ACHROMA_C:
        return "black" if L < 0.33 else "white" if L > 0.84 else "gray"
    if h >= 355 or h < 42:
        if L >= 0.78:
            return "pink"
        if h >= 20 and L < 0.45 and C < 0.12:
            return "brown"
        return "red"
    if h < 75:
        return "brown" if (L < 0.6 or (C < 0.08 and L < 0.72)) else "orange"
    if h < 120:
        if L < 0.55:
            return "brown" if h < 95 else "green"
        return "yellow"
    if h < 180:
        return "green"
    if h < 275:
        return "blue"
    if h < 330:
        return "purple"
    return "pink" if L >= 0.55 else "purple"


def colorfulness(rgb255: np.ndarray) -> float:
    r, g, b = rgb255[:, 0], rgb255[:, 1], rgb255[:, 2]
    rg = r - g
    yb = 0.5 * (r + g) - b
    return float(np.sqrt(rg.std() ** 2 + yb.std() ** 2)
                 + 0.3 * np.sqrt(rg.mean() ** 2 + yb.mean() ** 2))


def kmeans(x: np.ndarray, k: int, seed: int, iters: int = 20):
    """numpy の k-means（kmeans++ 初期化）。返り値: (centers, labels)。"""
    rng = np.random.default_rng(seed)
    n = len(x)
    centers = [x[rng.integers(n)]]
    d2 = ((x - centers[0]) ** 2).sum(1)
    for _ in range(1, k):
        total = d2.sum()
        idx = rng.integers(n) if total <= 0 else rng.choice(n, p=d2 / total)
        centers.append(x[idx])
        d2 = np.minimum(d2, ((x - x[idx]) ** 2).sum(1))
    c = np.array(centers)
    labels = np.zeros(n, dtype=int)
    for _ in range(iters):
        labels = ((x[:, None, :] - c[None, :, :]) ** 2).sum(-1).argmin(1)
        new = np.array([x[labels == j].mean(0) if (labels == j).any() else c[j]
                        for j in range(k)])
        if np.allclose(new, c):
            break
        c = new
    return c, labels


HL, HA = 8, 9
L_EDGES = np.linspace(0, 1, HL + 1)
A_EDGES = np.linspace(-0.3, 0.3, HA + 1)


def lab_histogram(lab: np.ndarray) -> np.ndarray:
    li = np.clip(np.digitize(lab[:, 0], L_EDGES) - 1, 0, HL - 1)
    ai = np.clip(np.digitize(lab[:, 1], A_EDGES) - 1, 0, HA - 1)
    bi = np.clip(np.digitize(lab[:, 2], A_EDGES) - 1, 0, HA - 1)
    h = np.bincount((li * HA + ai) * HA + bi, minlength=HL * HA * HA).astype(float)
    return h / h.sum()


def center_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    s = min(w, h)
    return img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))


def open_small(path, px: int) -> Image.Image:
    """大きな JPEG も縮小デコード（draft）で速く開く。"""
    im = Image.open(path)
    try:
        im.draft("RGB", (px * 2, px * 2))
    except Exception:  # noqa: BLE001 — JPEG 以外は draft 不可
        pass
    im = im.convert("RGB")
    im.thumbnail((px * 2, px * 2))
    return im


def analyse(img: Image.Image, seed: int) -> dict:
    """1 枚の写真の色の特徴（調色板・ヒストグラム・鮮やかさ・代表色）。"""
    small = img.copy()
    small.thumbnail((SAMPLE_PX, SAMPLE_PX), Image.LANCZOS)
    rgb255 = np.asarray(small, dtype=np.float64).reshape(-1, 3)
    lab = srgb_to_oklab(rgb255 / 255.0)
    k = min(K, len(np.unique(rgb255, axis=0)))
    cent, lbl = kmeans(lab, k, seed)
    counts = np.bincount(lbl, minlength=k).astype(float)
    props = counts / counts.sum()
    palette = []
    for i in np.argsort(-props):
        if props[i] < MIN_PROP or counts[i] == 0:
            continue
        mean_rgb = rgb255[lbl == i].mean(axis=0)
        L, C, h = lch(cent[i])
        palette.append({
            "hex": "#%02x%02x%02x" % tuple(int(round(x)) for x in mean_rgb),
            "p": float(props[i]),
            "lab": [round(float(v), 3) for v in cent[i]],
            "C": C, "h": h, "L": L, "name": color_name(L, C, h),
        })
    total = sum(p["p"] for p in palette) or 1.0
    for p in palette:
        p["p"] = round(p["p"] / total, 3)
    scores = [p["p"] * min(1.0, p["C"] / 0.10) for p in palette]
    best = int(np.argmax(scores))
    chromatic = not (scores[best] < 0.07 or palette[best]["C"] < 0.05)
    rep = best if chromatic else 0
    mean_l = float(sum(q["p"] * q["L"] for q in palette))
    return {
        "palette": palette, "rep": rep, "chromatic": chromatic,
        "h": palette[rep]["h"], "C": palette[rep]["C"],
        "L": palette[rep]["L"] if chromatic else mean_l, "meanL": mean_l,
        "cf": colorfulness(rgb255), "hist": lab_histogram(lab).tolist(),
    }


# ── 格子レイアウト（色轮・色相×明度） ─────────────────────────────

def grid_assign(points: np.ndarray, cells: np.ndarray) -> np.ndarray:
    """各点を重ならない格子に割り当てる（距離の短い組から貪欲に）。"""
    n = len(points)
    cost = ((points[:, None, :] - cells[None, :, :]) ** 2).sum(-1)
    order = np.argsort(cost, axis=None, kind="stable")
    used_p = np.zeros(n, dtype=bool)
    used_c = np.zeros(len(cells), dtype=bool)
    out = np.zeros((n, 2), dtype=int)
    left = n
    ncell = len(cells)
    for flat in order:
        p, c = divmod(int(flat), ncell)
        if used_p[p] or used_c[c]:
            continue
        used_p[p] = used_c[c] = True
        out[p] = cells[c].round().astype(int)
        left -= 1
        if left == 0:
            break
    return out


def wheel_layout(info: list[dict]) -> np.ndarray:
    n = len(info)
    pts = []
    for it in info:
        if it["chromatic"]:
            r = 0.28 + 0.72 * min(1.0, it["C"] / 0.2)
            pts.append((r * math.cos(math.radians(it["h"])),
                        -r * math.sin(math.radians(it["h"]))))
        else:
            pts.append((0.0, (0.5 - it["L"]) * 0.36))
    pts = np.array(pts, dtype=float).reshape(-1, 2)
    R = math.sqrt(max(n, 1) / math.pi) + 1.5
    while True:
        rng = np.arange(-math.ceil(R), math.ceil(R) + 1)
        gx, gy = np.meshgrid(rng, rng)
        mask = gx ** 2 + gy ** 2 <= R * R
        cells = np.stack([gx[mask], gy[mask]], -1).astype(float)
        if len(cells) >= n:
            break
        R += 0.5
    return grid_assign(pts * R, cells)


def hue_light_layout(info: list[dict]) -> np.ndarray:
    n = len(info)
    rows = max(1, int(math.ceil(math.sqrt(max(n, 1) / 2.4))))
    cols = int(math.ceil(max(n, 1) / rows)) + 2
    pts = []
    for it in info:
        x = 0.03 if not it["chromatic"] else 0.09 + 0.91 * (((it["h"] - 15) % 360) / 360)
        pts.append((x * (cols - 1), (1 - it["L"]) * (rows - 1)))
    gx, gy = np.meshgrid(np.arange(cols), np.arange(rows))
    cells = np.stack([gx.ravel(), gy.ravel()], -1).astype(float)
    return grid_assign(np.array(pts, dtype=float).reshape(-1, 2), cells)


def spectrum_key(it: dict):
    if not it["chromatic"]:
        return (1, -it["L"], 0)
    return (0, int(((it["h"] - 15) % 360) // 12), -it["L"])


# ── キャッシュ ───────────────────────────────────────────────────────

def explore_dir():
    d = data_dir() / "explore"
    (d / "bundles").mkdir(parents=True, exist_ok=True)
    return d


_FEAT_LOCK = threading.Lock()


def _load_features() -> dict:
    p = explore_dir() / "features.json"
    if not p.is_file():
        return {}
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
        return d.get("items", {}) if d.get("version") == FEATURE_VERSION else {}
    except (OSError, ValueError):
        return {}


def _save_features(items: dict) -> None:
    p = explore_dir() / "features.json"
    tmp = p.with_suffix(".part")
    tmp.write_text(json.dumps({"version": FEATURE_VERSION, "items": items}),
                   encoding="utf-8")
    tmp.replace(p)


# ── ジョブ ───────────────────────────────────────────────────────────

@dataclass
class ExploreJob:
    id: str
    status: str = "running"   # running / done / error
    phase: str = "analyse"    # analyse / layout / atlas
    done: int = 0
    total: int = 0
    key: str = ""
    count: int = 0
    error: str = ""
    started: float = field(default_factory=time.time)


_JOBS: dict[str, ExploreJob] = {}


def _bundle_key(recs: list[SignRecord]) -> str:
    h = hashlib.sha1(f"v{BUNDLE_VERSION}".encode())
    for r in recs:
        h.update(f"{r.id}:{r.photo_file_name}:{r.updated_at}|".encode())
    return h.hexdigest()[:16]


def _record_payload(rec: SignRecord, it: dict) -> dict:
    data = json.loads(rec.data_json)
    out = {
        "id": rec.sign_id, "rid": rec.id, "d": rec.display_id or rec.sign_id,
        "ph": rec.photo_file_name, "t": rec.captured_at or data.get("採集日時", ""),
        "main": lang_codes(data.get("主要言語", "")),
        "aux": lang_codes(data.get("補助言語", "")),
        "f": {k: norm_value(data.get(col, "")) for k, col in FIELDS.items()},
        "note": data.get("備考", ""),
    }
    if rec.latitude is not None and rec.longitude is not None:
        out["lat"], out["lon"] = rec.latitude, rec.longitude
        out["x"] = round(PROJ_X[0] * rec.longitude + PROJ_X[1], 1)
        out["y"] = round(PROJ_Y[0] * rec.latitude + PROJ_Y[1], 1)
    else:  # 位置なし: 地図表示では左上の外側にまとめる（他の表示には影響しない）
        out["lat"] = out["lon"] = None
        out["x"], out["y"] = -40.0, -40.0
    return out


def _build(job: ExploreJob, filters: dict) -> None:
    with Session(get_engine()) as session:
        recs = [r for r in _load_records(session, filters)
                if r.photo_file_name and (photos_dir() / r.photo_file_name).is_file()]
    recs.sort(key=lambda r: (r.captured_at or "", r.id))
    job.total = len(recs)
    job.count = len(recs)
    key = _bundle_key(recs)
    out = explore_dir() / "bundles" / key
    if (out / "data.js").is_file() and (out / "atlas.webp").is_file():
        job.key, job.done, job.status = key, job.total, "done"
        return
    if not recs:
        # 写真のある記録が無い範囲は「空」として正常終了（UI は失敗ではなく案内を出す）。
        job.status = "done"
        return

    # 1) 写真ごとの色の特徴（キャッシュに無いものだけ計算）
    with _FEAT_LOCK:
        feats = _load_features()
    atlas_rows = math.ceil(len(recs) / ATLAS_COLS)
    atlas = Image.new("RGBA", (ATLAS_COLS * TILE, atlas_rows * TILE), (0, 0, 0, 0))
    big = Image.new("L", (TILE * 4, TILE * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, TILE * 4 - 1, TILE * 4 - 1], radius=int(TILE * 4 * 0.14), fill=255)
    tile_mask = big.resize((TILE, TILE), Image.LANCZOS)
    info: list[dict] = []
    kept: list[SignRecord] = []
    changed = False
    for n_done, rec in enumerate(recs, 1):
        job.done = n_done
        try:
            img = open_small(photos_dir() / rec.photo_file_name, max(SAMPLE_PX, TILE))
        except Exception:  # noqa: BLE001 — 壊れた写真 1 枚で全体を止めない（その記録だけ外す）
            continue
        i = len(kept)
        kept.append(rec)
        fk = f"{rec.id}:{rec.photo_file_name}"
        it = feats.get(fk)
        if it is None:
            it = analyse(img, seed=rec.id)
            feats[fk] = it
            changed = True
        info.append(it)
        tile = center_square(img).resize((TILE, TILE), Image.LANCZOS)
        atlas.paste(tile, ((i % ATLAS_COLS) * TILE, (i // ATLAS_COLS) * TILE), tile_mask)
    if changed:
        with _FEAT_LOCK:
            merged = _load_features()
            merged.update(feats)
            _save_features(merged)

    recs = kept
    job.count = len(recs)
    if not recs:
        job.status = "done"
        return
    rows_used = math.ceil(len(recs) / ATLAS_COLS) * TILE
    if atlas.size[1] > rows_used:  # 外した写真のぶん、余った行を切り詰める
        atlas = atlas.crop((0, 0, atlas.size[0], rows_used))

    # 2) 色の近さ（平滑化ヒストグラムの cos 類似）とレイアウト
    job.phase = "layout"
    n = len(recs)
    hists = np.array([it["hist"] for it in info])
    lc = (L_EDGES[:-1] + L_EDGES[1:]) / 2
    ac = (A_EDGES[:-1] + A_EDGES[1:]) / 2
    centers = np.array(np.meshgrid(lc, ac, ac, indexing="ij")).reshape(3, -1).T
    d2 = ((centers[:, None, :] - centers[None, :, :]) ** 2).sum(-1)
    kern = np.exp(-d2 / (2 * 0.06 ** 2))
    V = np.sqrt(hists) @ kern
    V /= np.linalg.norm(V, axis=1, keepdims=True)
    S = V @ V.T
    np.fill_diagonal(S, -1)
    nb = np.argsort(-S, axis=1)[:, :min(N_NEIGHBORS, max(0, n - 1))]
    wheel = wheel_layout(info)
    hl = hue_light_layout(info)
    order = sorted(range(n), key=lambda i: spectrum_key(info[i]))
    spec_rank = np.empty(n, dtype=int)
    spec_rank[order] = np.arange(n)
    cf_all = np.array([it["cf"] for it in info])
    p99 = float(np.percentile(cf_all, 99)) or 1.0

    records = []
    for i, (rec, it) in enumerate(zip(recs, info)):
        rep = it["palette"][it["rep"]]
        r = _record_payload(rec, it)
        r.update({
            "pal": [[q["hex"], q["p"], *q["lab"], q["name"]] for q in it["palette"]],
            "rep": it["rep"],
            "cn": rep["name"] if it["chromatic"] else (
                "black" if rep["L"] < 0.33 else "white" if rep["L"] > 0.84 else "gray"),
            "chr": it["chromatic"],
            "hue": round(rep["h"], 1),
            "L": round(it["meanL"], 3),
            "cf": round(float(min(1.0, it["cf"] / p99)), 3),
            "sp": int(spec_rank[i]),
            "wh": [int(v) for v in wheel[i]],
            "hl": [int(v) for v in hl[i]],
            "nb": [int(j) for j in nb[i]],
        })
        records.append(r)

    # 3) 書き出し（一時ファイル → 置換）
    job.phase = "atlas"
    out.mkdir(parents=True, exist_ok=True)
    buf = io.BytesIO()
    atlas.save(buf, "WEBP", quality=82, method=4)
    (out / "atlas.webp").write_bytes(buf.getvalue())
    used = sorted({c for r in records for c in r["main"] + r["aux"]})
    bundle = {
        "records": records,
        "langs": {c: {"name": LANG_NAMES.get(c, c)} for c in used},
        "atlas": {"file": "atlas.webp", "tile": TILE, "cols": ATLAS_COLS},
        "colorNames": COLOR_NAMES,
        "built": time.strftime("%Y-%m-%d %H:%M"),
    }
    tmp = out / "data.js.part"
    tmp.write_text("window.LLV_DATA = " + json.dumps(bundle, ensure_ascii=False) + ";",
                   encoding="utf-8")
    tmp.replace(out / "data.js")
    job.key = key
    job.status = "done"


def _run(job: ExploreJob, filters: dict) -> None:
    try:
        _build(job, filters)
    except Exception as e:  # noqa: BLE001 — 失敗は UI に理由を出す
        job.status = "error"
        job.error = str(e)


@router.post("/explore/build")
def start_explore_build(payload: dict = Body(default={})):
    """範囲（筛选 / ids）の探索バンドルを作る。既にあれば即 done。"""
    filters = _filters_kwargs(payload)
    job = ExploreJob(id=uuid.uuid4().hex[:12])
    _JOBS[job.id] = job
    threading.Thread(target=_run, args=(job, filters), daemon=True).start()
    return {"jobId": job.id}


@router.get("/explore/jobs/{job_id}")
def explore_job(job_id: str):
    job = _JOBS.get(job_id)
    if job is None:
        raise HTTPException(404, f"ジョブが見つかりません: {job_id}")
    return {"id": job.id, "status": job.status, "phase": job.phase,
            "done": job.done, "total": job.total, "key": job.key,
            "count": job.count, "error": job.error}


def _bundle_file(key: str, name: str):
    if not key.isalnum() or name not in ("data.js", "atlas.webp"):
        raise HTTPException(400, "不正な指定です")
    p = explore_dir() / "bundles" / key / name
    if not p.is_file():
        raise HTTPException(404, "探索データがありません（先に /explore/build）")
    return p


@router.get("/explore/bundles/{key}/data.js")
def bundle_data(key: str):
    p = _bundle_file(key, "data.js")
    return Response(p.read_bytes(), media_type="application/javascript; charset=utf-8",
                    headers={"Cache-Control": "no-cache"})


@router.get("/explore/bundles/{key}/atlas.webp")
def bundle_atlas(key: str):
    return FileResponse(_bundle_file(key, "atlas.webp"), media_type="image/webp")
