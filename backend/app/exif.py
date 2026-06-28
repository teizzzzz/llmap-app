"""
EXIF/GPS 抽出。mapv2.0/ll_rename_gui.py の extract_exif / dms_to_decimal を
バイト列入力に対応させて移植。
"""
from __future__ import annotations

import io
from typing import Optional

import piexif
from PIL import Image


def dms_to_decimal(dms, ref) -> Optional[float]:
    try:
        d = dms[0][0] / dms[0][1]
        m = dms[1][0] / dms[1][1]
        s = dms[2][0] / dms[2][1]
        dec = d + m / 60 + s / 3600
        if ref in ["S", "W"]:
            dec = -dec
        return round(dec, 7)
    except Exception:
        return None


def extract_exif(data: bytes) -> dict:
    """写真バイト列から撮影日時と GPS を取り出す。無ければ None。"""
    out = {"datetime": None, "lat": None, "lng": None}
    try:
        img = Image.open(io.BytesIO(data))
        raw = img.info.get("exif")
        if not raw:
            return out
        exif = piexif.load(raw)
        dt = exif.get("Exif", {}).get(piexif.ExifIFD.DateTimeOriginal)
        if dt:
            out["datetime"] = dt.decode("utf-8", errors="ignore")
        gps = exif.get("GPS", {})
        if gps:
            ld = gps.get(piexif.GPSIFD.GPSLatitude)
            lr = gps.get(piexif.GPSIFD.GPSLatitudeRef)
            nd = gps.get(piexif.GPSIFD.GPSLongitude)
            nr = gps.get(piexif.GPSIFD.GPSLongitudeRef)
            if ld and lr and nd and nr:
                lr = lr.decode() if isinstance(lr, bytes) else lr
                nr = nr.decode() if isinstance(nr, bytes) else nr
                out["lat"] = dms_to_decimal(ld, lr)
                out["lng"] = dms_to_decimal(nd, nr)
    except Exception:
        pass
    return out


def normalize_datetime(exif_dt: Optional[str]) -> str:
    """EXIF の 'YYYY:MM:DD HH:MM:SS' を標準 'YYYY-MM-DD HH:MM:SS' に。"""
    if not exif_dt:
        return ""
    try:
        date_part, _, time_part = exif_dt.partition(" ")
        return f"{date_part.replace(':', '-')} {time_part}".strip()
    except Exception:
        return exif_dt
