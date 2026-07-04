"""
CSV 入出力。mapv2.0 の data.csv と互換（utf-8-sig・標準表頭）。
"""
from __future__ import annotations

import csv
import io

from .schema import CSV_HEADER, Sign


def signs_to_csv(signs: list[Sign]) -> str:
    """標準表頭で CSV 文字列を返す（Excel 互換のため呼び出し側で utf-8-sig 出力）。"""
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=CSV_HEADER, extrasaction="ignore")
    writer.writeheader()
    for s in signs:
        row = s.model_dump(by_alias=True)  # status -> "_status"
        writer.writerow({k: row.get(k, "") for k in CSV_HEADER})
    return buf.getvalue()


def csv_to_signs(text: str) -> list[Sign]:
    """既存 data.csv を読み込み Sign に変換（多人化前の移行用）。"""
    reader = csv.DictReader(io.StringIO(text))
    out: list[Sign] = []
    for row in reader:
        data = {k: v for k, v in row.items() if k in CSV_HEADER}
        for num in ("緯度", "経度"):
            if num in data:  # 空欄は None（GPS なし）として読む
                try:
                    data[num] = float(data[num]) if data[num] else None
                except ValueError:
                    data[num] = None
        out.append(Sign(**data))
    return out
