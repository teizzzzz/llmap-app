"""
字段标准（PROJECT_STANDARD.md §6/§7 を踏襲）。
CSV互換のための標準表頭・分类值・SignID/写真ID規約をここに集約する。
"""
from __future__ import annotations

import re
from datetime import datetime
from typing import Optional, Union

from pydantic import BaseModel, ConfigDict, Field


def split_multi(v: str | None) -> list[str]:
    """複数選択字段（"日本語/韓国語" 等）を個々の値に分割（アプリ splitMulti と同一）。"""
    return [p.strip() for p in re.split(r"[/・、,]", v or "")
            if p.strip() and p.strip() != "—"]

# ── CSV 標準表頭（採集字段定義表 v3 三語重構版） ──
# A 識別情報（系統/自動）→ 名称 → B 言語·文字 → C 物質·空間·時間 → D 解読·判定。
CSV_HEADER = [
    # A 識別情報
    # CaptureID が一意性の中心。写真ID/全景写真ファイル名 は旧CSV互換のため保持
    # （新規レコードでは 写真ID=CaptureID、全景写真ファイル名=元写真ファイル名）。
    "SignID", "_status",
    "CaptureID", "DisplayID", "採集者ID", "地区コード", "LocalSeq",
    "CropSuffix", "CropRect",
    "写真ID", "写真ファイル名", "元写真ファイル名", "全景写真ファイル名",
    "緯度", "経度", "採集日時",
    "EntryMode", "DataStatus", "SchemaVersion", "AppVersion",
    # 名称（暫定保留）
    "名称",
    # B 言語·文字
    "文字性", "主要言語", "補助言語", "装飾の言語", "文字体系", "多言語関係",
    # C 物質·空間·時間
    "担体類型", "空間階層", "時間性", "可読性", "重ね書き",
    # D 解読·判定
    "設置主体", "ディスコース類型", "製作品質", "備考",
]

# ── 状態（判定来源を統合）── pending=未処理 / ai=AI下書未校 /
#    human-reviewed=人が記入or校閲 / final=確定。
STATUS_VALUES = ["pending", "ai", "human-reviewed", "final"]

# _status → DataStatus（Console 審核状態）の対応（アプリ models.dart と同一）。
DATA_STATUS_MAP = {
    "pending": "raw",
    "ai": "ai_drafted",
    "human-reviewed": "reviewed",
    "final": "verified",
}

# システム/自動生成字段（アプリ AppSchema.systemFields と同一）。
# Console の編集 API では _status / DataStatus を除きロックする。
SYSTEM_FIELDS = [
    "SignID", "_status",
    "CaptureID", "DisplayID", "採集者ID", "地区コード", "LocalSeq",
    "CropSuffix", "CropRect",
    "写真ID", "写真ファイル名", "元写真ファイル名", "全景写真ファイル名",
    "緯度", "経度", "採集日時",
    "EntryMode", "DataStatus", "SchemaVersion", "AppVersion",
]

# 言語の正準値（主要/補助/装飾で共用）。
LANGUAGES = ["日本語", "韓国語", "中国語", "ベトナム語", "ネパール語", "英語", "その他"]

# 複数選択かつ自由追加できる字段（フロントは「/」区切り文字列で保存）。
MULTI_FIELDS = ["主要言語", "補助言語", "装飾の言語", "文字体系"]

# ── 分类值。フロントのフォーム選択肢として配信する ──
ENUMS: dict[str, list[str]] = {
    # B 言語·文字（言語3つと文字体系は複数選択・自由追加可 = MULTI_FIELDS）
    "文字性": ["含文字", "純記号", "対象外"],
    "主要言語": LANGUAGES,
    "補助言語": LANGUAGES,
    "装飾の言語": LANGUAGES,
    "文字体系": [
        "漢字", "平仮名", "片仮名", "ローマ字", "ハングル(한글)",
        "デーヴァナーガリー", "ビルマ文字", "タイ文字", "ベンガル文字",
        "アラビア", "キリル", "その他", "無",
    ],
    "多言語関係": ["単言語型", "複製型", "重複型", "部分翻訳型"],
    # C 物質·空間·時間
    "担体類型": [
        "路面固定", "壁面", "看板", "移動物体(停車中)", "ステッカー", "横断幕", "その他",
    ],
    "空間階層": ["低位・接近可能層", "中位・視線層", "高位・天際層"],
    "時間性": ["常設", "臨時・季節的", "一過性"],
    "可読性": ["完全可読", "部分可読", "判読困難"],
    "重ね書き": ["無", "有(新が旧を上書き)", "有(多層の堆積)"],
    # D 解読·判定
    "設置主体": [
        "行政・公共機関", "商業・チェーン", "商業・個人店", "個人", "団体", "不明",
    ],
    "ディスコース類型": ["規約", "基礎設施", "商業", "越境", "判読不能", "その他"],
    "製作品質": ["専門印刷", "半専門", "手作り"],
}

# AI が下書きする字段。名称含め全編集字段が AI 下書対象（人が校閲して確定）。
AI_FIELDS = [
    "名称",
    "文字性", "主要言語", "補助言語", "装飾の言語", "文字体系", "多言語関係",
    "担体類型", "空間階層", "時間性", "可読性", "重ね書き",
    "設置主体", "ディスコース類型", "製作品質", "備考",
]

# 言語別の地図色。ENUMS の主要言語と一致させる。
LANGUAGE_COLORS = {
    "日本語": "#2563eb",
    "韓国語": "#15946f",
    "中国語": "#b76e00",
    "ベトナム語": "#d6336c",
    "ネパール語": "#7048e8",
    "英語": "#7c3aed",
    "その他": "#637083",
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
    # 新契約（アプリ v1.5.0〜）。旧データは空でよい。
    CaptureID: str = ""
    DisplayID: str = ""
    採集者ID: str = ""
    地区コード: str = ""
    LocalSeq: Union[int, str] = ""
    CropSuffix: str = ""
    CropRect: str = ""  # JSON 文字列 {"x":..,"y":..,"w":..,"h":..}（相対座標 0..1）
    元写真ファイル名: str = ""
    # 溯源字段（v1.5.1〜）。旧データは空でよい。
    EntryMode: str = ""       # 採集方式（現行フローは standard）
    DataStatus: str = ""      # Console 審核状態（raw/ai_drafted/reviewed/verified…）
    SchemaVersion: str = ""   # データ契約バージョン（例 1.5）
    AppVersion: str = ""      # 採集時のアプリ版（例 v1.5.1）
    # 旧字段（互換のため保持。新規レコードでは 写真ID=CaptureID）
    写真ID: str = ""
    写真ファイル名: str = ""
    全景写真ファイル名: str = ""
    緯度: Optional[float] = None
    経度: Optional[float] = None
    採集日時: str = ""
    名称: str = ""
    # B 言語·文字
    文字性: str = ""
    主要言語: str = ""
    補助言語: str = "—"
    装飾の言語: str = "—"
    文字体系: str = ""
    多言語関係: str = ""
    # C 物質·空間·時間
    担体類型: str = ""
    空間階層: str = ""
    時間性: str = ""
    可読性: str = ""
    重ね書き: str = ""
    # D 解読·判定
    設置主体: str = ""
    ディスコース類型: str = ""
    製作品質: str = ""
    備考: str = ""
    # 多人共享の予約フィールド（CSV標準表頭には含めない）
    user_id: Optional[str] = None


# ── 新ID契約（アプリ imaging.dart と同一規則。docs/data-contract.md 参照） ──

def make_capture_id(area: str, collector_id: str, captured_at: datetime) -> str:
    """CaptureID: AREA-COLLECTORID-YYMMDDHHMMSSmmm。1回の撮影イベントの一意ID。"""
    ts = captured_at.strftime("%y%m%d%H%M%S") + f"{captured_at.microsecond // 1000:03d}"
    head = area.upper() if not collector_id.strip() else f"{area.upper()}-{collector_id.strip()}"
    return f"{head}-{ts}"


def make_sign_id(capture_id: str, suffix: str) -> str:
    """SignID: CaptureID-suffix。"""
    return f"{capture_id}-{suffix}"


def make_display_id(area: str, captured_at: datetime, seq: int, suffix: str) -> str:
    """DisplayID: AREA-YYYYMMDD-SEQ-suffix。表示専用（主キーにしない）。"""
    return f"{area.upper()}-{captured_at.strftime('%Y%m%d')}-{seq:03d}-{suffix}"


def source_photo_name(capture_id: str) -> str:
    """元写真（原始完整写真）のファイル名: CaptureID-source.jpg。"""
    return f"{capture_id}-source.jpg"


def crop_photo_name(capture_id: str, suffix: str) -> str:
    """裁切写真のファイル名: CaptureID-<suffix>.jpg。"""
    return f"{capture_id}-{suffix}.jpg"


# ── 旧ID採番（legacy）。旧データの解釈用に保持。新規採番には使わない ──

def photo_id(area: str, yyyymmdd: str, seq: int) -> str:
    """[legacy] 写真ID: AREA-YYYYMMDD-NNN。新規レコードでは 写真ID=CaptureID。"""
    return f"{area.upper()}-{yyyymmdd}-{seq:03d}"


def sign_id(area: str, seq: int, suffix: str) -> str:
    """[legacy] SignID: AREA-SNNN-suffix。新規は make_sign_id を使う。"""
    return f"{area.upper()}-S{seq:03d}-{suffix}"
