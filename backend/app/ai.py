"""
AI判定。mapv2.0/ll_ai_judge_gui.py の prompt / image_to_base64 / judge_* を移植。
API key はコードに書かず環境変数から読む（§8）。
"""
from __future__ import annotations

import base64
import io
import json
import os
import re
from typing import Optional

from PIL import Image, ImageOps

from .schema import AI_FIELDS

# 採集字段定義表 v3 に準拠。AI は「下書き(ai)」を担い、人が校閲して確定する。
SYSTEM_PROMPT = (
    "あなたは言語景観（linguistic landscape）研究の専門家です。"
    "都市の公共空間にある看板・サイン・貼り紙・標識の写真を分析し、研究用の字段を下書きします。"
    "方針は「採集從寬・分析從嚴」: 客観的に観察できることを記し、推測が必要な場合は備考に根拠を書きます。"
    "各字段は与えられた選択肢から最も適切な値を選びます"
    "（「複数可」と示した言語・文字体系のみ、等価なものは「/」で併記してよい）。"
    "読めない言語でも文字体系は字形から判定でき、内容判定が要る字段は「判読不能」を選びます。"
    "必ず指定された JSON 形式のみで回答し、前置き・説明・マークダウン・コードフェンスは付けません。"
)

FIELD_GUIDE = {
    "名称": "標識内容の短い名称（自由記述）",
    "文字性": "含文字 / 純記号 / 対象外。駐禁・矢印・トイレ図=純記号；装飾挿絵・図形のみのロゴ=対象外；記号+文字の混在→含文字",
    "主要言語": (
        "視覚的に支配的な言語。優先順位 ①面積最大 > ②中心 > ③字号最大。"
        "日本語/韓国語/中国語/ベトナム語/ネパール語/英語/その他。等大の並行は「日本語/韓国語」のように併記"
    ),
    "補助言語": "次要だが情報を伝える言語（複数可、無は —）。外すと情報が欠ける→補助",
    "装飾の言語": "情報をほぼ伝えず装飾/ブランド/雰囲気のための言語（複数可、無は —）。例 英語(ブランド名)。見栄えだけ→装飾",
    "文字体系": "書記体系（言語とは別、複数可）。漢字/平仮名/片仮名/ローマ字/ハングル/デーヴァナーガリー/ビルマ文字/タイ文字/ベンガル文字/アラビア/キリル/その他/無。混在は「/」で併記",
    "多言語関係": "単言語型 / 複製型 / 重複型 / 部分翻訳型（Reh 2004）。単語なら単言語型",
    "担体類型": "路面固定 / 壁面 / 看板 / 移動物体(停車中) / ステッカー / 横断幕 / その他。キッチンカー・停車中トラック→移動物体(停車中)",
    "空間階層": "低位・接近可能層 / 中位・視線層 / 高位・天際層。環境の客観参照（部位・階・高度帯）で判定し採集者の身長に依らない",
    "時間性": "常設 / 臨時・季節的 / 一過性。選挙ポスター・季節販促→臨時・季節的",
    "可読性": "完全可読 / 部分可読 / 判読困難。物理的明瞭度のみ（言語が分かるかとは切り離す）。劣化・褪色・破損→部分可読/判読困難",
    "重ね書き": "無 / 有(新が旧を上書き) / 有(多層の堆積)。旧字を新字が覆う・ステッカー堆積→有",
    "設置主体": "行政・公共機関 / 商業・チェーン / 商業・個人店 / 個人 / 団体 / 不明。客観的に「誰が立てたか」",
    "ディスコース類型": (
        "規約 / 基礎設施 / 商業 / 越境 / 判読不能 / その他（Scollon 2003）。"
        "判定順: 越境→規約→基礎設施→商業。読めない言語は判読不能"
    ),
    "製作品質": "専門印刷 / 半専門 / 手作り",
    "備考": "分類の迷い・例外・補足や境界判断の理由。採集/除外理由は「【判断】」を接頭辞に",
}


def build_prompt(fields: Optional[list[str]] = None) -> str:
    fields = fields or AI_FIELDS
    body = ",\n".join(
        f'  "{f}": "{FIELD_GUIDE.get(f, "判定結果")}"' for f in fields
    )
    return (
        "この写真の看板・サイン・貼り紙を分析してください。\n"
        "以下のJSON形式のみで回答してください。前置き・説明・マークダウンは不要です：\n\n"
        f"{{\n{body}\n}}"
    )


def crop_image(data: bytes, x: float, y: float, w: float, h: float) -> bytes:
    """相対座標(0..1)の矩形で画像を切り出して JPEG バイト列を返す。"""
    img = Image.open(io.BytesIO(data))
    img = ImageOps.exif_transpose(img)
    if img.mode != "RGB":
        img = img.convert("RGB")
    W, H = img.size
    left = max(0, int(x * W))
    top = max(0, int(y * H))
    right = min(W, int((x + w) * W))
    bottom = min(H, int((y + h) * H))
    if right - left < 2 or bottom - top < 2:
        return data  # 無効な矩形は全景のまま
    cropped = img.crop((left, top, right, bottom))
    buf = io.BytesIO()
    cropped.save(buf, "JPEG", quality=90)
    return buf.getvalue()


def image_to_base64(data: bytes, max_size: int = 1024, quality: int = 75) -> str:
    """§9 のAI判定推奨: 最大辺1024 / quality75。"""
    img = Image.open(io.BytesIO(data))
    img = ImageOps.exif_transpose(img)
    if img.mode != "RGB":
        img = img.convert("RGB")
    w, h = img.size
    if max(w, h) > max_size:
        r = max_size / max(w, h)
        img = img.resize((int(w * r), int(h * r)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=quality)
    return base64.standard_b64encode(buf.getvalue()).decode("utf-8")


def _strip_json(text: str) -> dict:
    """モデル出力から最初の JSON オブジェクトを取り出す。"""
    text = text.strip()
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if not m:
        return {}
    try:
        return json.loads(m.group(0))
    except Exception:
        return {}


def judge_claude(b64: str, fields: Optional[list[str]] = None,
                 api_key: Optional[str] = None) -> dict:
    import anthropic

    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise RuntimeError("ANTHROPIC_API_KEY が設定されていません")
    client = anthropic.Anthropic(api_key=key)
    res = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64",
             "media_type": "image/jpeg", "data": b64}},
            {"type": "text", "text": build_prompt(fields)},
        ]}],
    )
    return _strip_json(res.content[0].text)


def judge_gemini(b64: str, fields: Optional[list[str]] = None,
                 api_key: Optional[str] = None) -> dict:
    from google import genai as google_genai
    import PIL.Image

    key = api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY が設定されていません")
    client = google_genai.Client(api_key=key)
    img = PIL.Image.open(io.BytesIO(base64.b64decode(b64)))
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=[SYSTEM_PROMPT + "\n\n" + build_prompt(fields), img],
    )
    return _strip_json(response.text)


def judge(data: bytes, provider: str = "claude",
          fields: Optional[list[str]] = None,
          api_key: Optional[str] = None) -> dict:
    """写真バイト列を圧縮してプロバイダに渡し、字段dictを返す。"""
    b64 = image_to_base64(data)
    if provider == "gemini":
        return judge_gemini(b64, fields, api_key)
    return judge_claude(b64, fields, api_key)
