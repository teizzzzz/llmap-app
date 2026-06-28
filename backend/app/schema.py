"""
字段标准（PROJECT_STANDARD.md §6/§7 を踏襲）。
CSV互換のための標準表頭・分类值・SignID/写真ID規約をここに集約する。
"""
from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

# ── CSV 標準表頭（§6.1） ──
CSV_HEADER = [
    "SignID", "_status", "写真ID", "写真ファイル名", "全景写真ファイル名",
    "緯度", "経度", "採集日時", "名称", "主要言語", "補助言語", "装飾的言語",
    "設置主体", "担体類型", "時間性", "可読性", "来源類型", "視認等級",
    "位置描述", "多言語関係", "想定受容者", "制作品質", "備考",
]

# ── 状態（§6.3） ──
STATUS_VALUES = ["pending", "ai", "modified", "reviewed"]

# ── 分类值（§7）。フロントのフォーム選択肢として配信する ──
ENUMS: dict[str, list[str]] = {
    "主要言語": ["日本語", "中文", "韓国語", "英語", "その他", "—"],
    "補助言語": ["日本語", "中文", "韓国語", "英語", "その他", "—"],
    "装飾的言語": ["英語(ブランド名)", "英語(装飾)", "その他", "—"],
    "設置主体": ["行政/公共機関", "商業", "個人/非正式", "不明"],
    "担体類型": [
        "建物固定(看板)", "建物固定(壁画)", "建物固定(門牌)",
        "移動物体(停車中)", "貼付物(ポスター)", "貼付物(ステッカー)",
        "路面固定", "デジタル表示(LED)", "その他",
    ],
    "時間性": ["常設", "臨時/季節的", "不明"],
    "可読性": ["完全可読", "部分可読", "不可読"],
    "来源類型": ["top-down(標準化)", "bottom-up(ローカル自作)", "不明"],
    "視認等級": ["歩行可読(<5m)", "近距可読(5-15m)", "遠距可読(>15m)"],
    "多言語関係": ["平行型", "補完型", "象徴型", "単言語型"],
    "想定受容者": ["本地住民", "特定コミュニティ", "観光客・外国人", "不明"],
    "制作品質": ["専門印刷", "半専門(印刷)", "手書き"],
}

# AI が記入してよい字段（§8）。現場依存字段は除外。
AI_FIELDS = [
    "名称", "主要言語", "補助言語", "装飾的言語",
    "設置主体", "担体類型", "来源類型", "多言語関係", "備考",
]

# 言語別の地図色（§10）
LANGUAGE_COLORS = {
    "日本語": "#2e6fdb", "中文": "#e07b1a", "韓国語": "#2aa84a",
    "英語": "#8e44ad", "その他": "#888888",
}


class CropRegion(BaseModel):
    """全景写真上での sign の框选矩形（0..1 の相対座標）。"""
    suffix: str = Field(..., description="同一写真内の sign 識別子: a, b, c ...")
    x: float = Field(..., ge=0, le=1)
    y: float = Field(..., ge=0, le=1)
    w: float = Field(..., gt=0, le=1)
    h: float = Field(..., gt=0, le=1)


class Sign(BaseModel):
    """CSV 標準字段に対応する1レコード。多人化のため user_id を予約。"""
    # 先頭アンダースコア字段は pydantic 予約のためエイリアスで扱う
    model_config = ConfigDict(populate_by_name=True)

    SignID: str
    status: str = Field("pending", alias="_status")
    写真ID: str
    写真ファイル名: str = ""
    全景写真ファイル名: str = ""
    緯度: Optional[float] = None
    経度: Optional[float] = None
    採集日時: str = ""
    名称: str = ""
    主要言語: str = ""
    補助言語: str = "—"
    装飾的言語: str = "—"
    設置主体: str = ""
    担体類型: str = ""
    時間性: str = ""
    可読性: str = ""
    来源類型: str = ""
    視認等級: str = ""
    位置描述: str = ""
    多言語関係: str = ""
    想定受容者: str = ""
    制作品質: str = ""
    備考: str = ""
    # 多人共享の予約フィールド（CSV標準表頭には含めない）
    user_id: Optional[str] = None


def photo_id(area: str, yyyymmdd: str, seq: int) -> str:
    """写真ID: AREA-YYYYMMDD-NNN （§5.2）"""
    return f"{area.upper()}-{yyyymmdd}-{seq:03d}"


def sign_id(area: str, seq: int, suffix: str) -> str:
    """SignID: AREA-SNNN-suffix （§5.4）"""
    return f"{area.upper()}-S{seq:03d}-{suffix}"
