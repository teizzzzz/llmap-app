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

SYSTEM_PROMPT = (
    "あなたは言語景観研究の専門家です。都市の公共空間の看板・サイン・貼り紙の"
    "写真を分析します。必ずJSON形式のみで回答してください。"
)

FIELD_GUIDE = {
    "名称": "看板の内容を簡潔に",
    "主要言語": "日本語 or 中文 or 韓国語 or 英語 or その他",
    "補助言語": "日本語 or 中文 or 韓国語 or 英語 or その他 or —",
    "装飾的言語": "英語(ブランド名) or 英語(装飾) or その他 or —",
    "設置主体": "行政/公共機関 or 商業 or 個人/非正式 or 不明",
    "担体類型": "建物固定(看板) or 建物固定(壁画) or 建物固定(門牌) or 移動物体(停車中) or 貼付物(ポスター) or 貼付物(ステッカー) or 路面固定 or デジタル表示(LED) or その他",
    "来源類型": "top-down(標準化) or bottom-up(ローカル自作) or 不明",
    "多言語関係": "平行型 or 補完型 or 象徴型 or 単言語型",
    "備考": "特記事項があれば簡潔に",
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
