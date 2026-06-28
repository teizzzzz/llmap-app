"""
採集データのローカル永続化（backend/data 配下）。
- photos/  : 全景写真と裁切写真の JPEG
完全ローカル運用が前提。将来クラウド化する場合もこの層を差し替えればよい。
"""
from __future__ import annotations

import io
from pathlib import Path

from PIL import Image, ImageOps

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
PHOTOS_DIR = DATA_DIR / "photos"


def _ensure() -> None:
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)


def save_panorama(photo_id: str, data: bytes) -> str:
    """全景写真を <写真ID>.jpg として保存し、ファイル名を返す。"""
    _ensure()
    name = f"{photo_id}.jpg"
    img = ImageOps.exif_transpose(Image.open(io.BytesIO(data)))
    if img.mode != "RGB":
        img = img.convert("RGB")
    img.save(PHOTOS_DIR / name, "JPEG", quality=90)
    return name


def save_crop(photo_id: str, suffix: str, data: bytes,
              x: float, y: float, w: float, h: float) -> str:
    """全景から相対矩形を切り出し <写真ID>-<suffix>.jpg として保存。"""
    _ensure()
    name = f"{photo_id}-{suffix}.jpg"
    img = ImageOps.exif_transpose(Image.open(io.BytesIO(data)))
    if img.mode != "RGB":
        img = img.convert("RGB")
    W, H = img.size
    left, top = max(0, int(x * W)), max(0, int(y * H))
    right, bottom = min(W, int((x + w) * W)), min(H, int((y + h) * H))
    if right - left >= 2 and bottom - top >= 2:
        img = img.crop((left, top, right, bottom))
    img.save(PHOTOS_DIR / name, "JPEG", quality=90)
    return name


def photo_path(name: str) -> Path:
    return PHOTOS_DIR / name


def exists(name: str) -> bool:
    return bool(name) and (PHOTOS_DIR / name).is_file()
