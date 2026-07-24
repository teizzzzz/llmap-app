"""
バッチ AI の判定エンジン（アプリ app/lib/ai.dart の忠実な移植）。
プロンプト・プロバイダ呼び出し・応答解析・併合規則をここに集約し、
ジョブ管理（ai_jobs.py）から切り離して純ロジックとしてテスト可能にする。

移植元と一字一句レベルで揃える（挙動の同一性が正しさの根拠）:
- _SYSTEM_PROMPT / _FIELD_GUIDE / build_prompt  ← ai.dart
- merge_ai_draft                                 ← record_ops.dart mergeAiDraft
モデル・max_tokens・画像縮小（最大辺1024/quality75）もアプリと同一。
"""
from __future__ import annotations

import base64
import io
import json
import re
from pathlib import Path

import httpx

from .schema import AI_FIELDS, split_multi

# 採集字段定義表 v6（2026-07-24）準拠。AI は「下書き(ai)」を担い、人が校閲して確定。
# v6 の 2 大規則:
#   1) 既存内容は消さない — 併合は merge_ai_draft が行うため、AI は備考に
#      「新規観察のみ」を書く（既存の再掲・書き換えをしない）。
#   2) 不確実は空欄 — 自信を持てない字段は "" を返し、推測で埋めない。
_SYSTEM_PROMPT = (
    "あなたは言語景観（linguistic landscape）研究の専門家です。"
    "都市の公共空間にある看板・サイン・貼り紙・標識の写真を分析し、研究用の字段を下書きします。"
    "方針は「採集從寬・分析從嚴」: 客観的に観察できることだけを記します。"
    "各字段は与えられた選択肢から最も適切な値を**そのままの表記**で選びます"
    "（「複数可」と示した言語のみ、等価なものは「/」で併記してよい。選択肢に無い言語名は直接記入してよい）。"
    "写真から判定できない・自信が持てない字段は、推測で埋めずに空文字列 \"\" を返します。"
    "内容を読む必要がある字段が読めない場合は「判读不能」を選びます。"
    "備考にはこの写真から新たに観察できたことだけを書き、判断理由は「【判断】」、"
    "同一載体上の同款重複数は「【数量】×N」の接頭辞を使います（既存データの再掲・書き換えはしない）。"
    "必ず指定された JSON 形式のみで回答し、前置き・説明・マークダウン・コードフェンスは付けません。"
)

# v6「人（AI 起草）」13 維度の判定ガイド（定義表の意思・例子列を圧縮）。
# 値は schema.ENUMS の正準表記と一字一句一致させること。
_FIELD_GUIDE: dict[str, str] = {
    "文字性":
        "文字 / 記号 / 対象外。第一軸=言語として読める文字を含むか。"
        "駐禁・矢印・トイレ図标=記号；装飾挿絵・純図形logo=対象外；記号+文字の混在=文字",
    "主要言語":
        "視覚的に支配的な言語（code preference）。判定順 ①視覚面積最大 → ②位置最中心 → ③字号最大。"
        "日本語/韓国語/中国語/ベトナム語/ネパール語/英語、他の言語は名前を直接記入。"
        "三項等権重なら「日本語/韓国語」のように併記し無理に一つへ絞らない。判別不能のみ「その他」",
    "補助言語":
        "次要だが情報を伝える言語（複数可、無は —）。"
        "口訣: それを外すと情報が欠ける→補助；見栄えだけ→装飾の言語へ",
    "装飾の言語":
        "ほぼ情報を伝えず装飾・ブランド識別・雰囲気のための言語（複数可、無は —）。"
        "欧文の格調的使用・芸術字logo。logoがブランド識別のみ→ここに記し主要言語に数えない",
    "多言語関係":
        "单语型 / 复制型 / 重复型 / 部分翻译型（Reh 2004: Monolingual/Duplicating/Overlapping/Fragmentary）。"
        "各言語の内容が完全同一→复制型；完全情報が一言語のみで他言語は断片訳→部分翻译型；単一言語→单语型",
    "担体類型":
        "无媒介 / 产品 / 贴纸 / 旗帜 / 海报 / 宣传册 / 夹心板 / 车辆 / 便签 / 其他。"
        "无媒介=文字が固定位置/物体に直接ある；产品=衣服・鞄・新聞等；海报=臨時掲示でA4より大きい紙；"
        "夹心板=路上の自立式看板(gatupratare)；车辆=自転車・車・バス・トラック等；"
        "便签=簡易レイアウトの臨時貼紙でA4未満・テープ/画鋲どめ",
    "放置位置":
        "建筑物上 / 柱子 / 公告板 / 屏幕 / 道路 / 市政设施设备 / 半可移动物体 / 其他。"
        "建筑物上=壁・扉・窓；柱子=建物から独立した柱；屏幕=自立式(デジタル/アナログ)；"
        "道路=歩道・広場・駐車場を含む；市政设施设备=パーキングメーター・郵便ポスト・配電箱等；"
        "半可移动物体=ゴミ箱・ベンチ・テーブル・足場・工事フェンス・コンテナ等；其他=人など",
    "時間性":
        "常设 / 临时·季节性 / 一过性。判定順: ①明確な失効日付があれば日付に従う "
        "②固定方式を見る: 溶接・ボルト→常设／フック・掛け外し可→临时·季节性／テープ・画鋲・易剥離→一过性 "
        "③材質で曖昧なら内容で判断。区分線: 撤去したら終わり=一过性；来季また掛かる=临时·季节性",
    "可読性":
        "完全可读 / 部分可读 / 判读困难。文字の物理的明瞭度のみ（言語が分かるかとは切り離す）。"
        "劣化・褪色・破損→部分可读/判读困难。部分可读の場合は備考に理由（磨損か字体芸術化か）を必ず書く",
    "重ね書き":
        "无 / 有（新覆旧） / 有（多层堆叠）。物理的な叠写・覆盖・修改の痕跡。"
        "旧字を新字が覆う・ステッカーの層状堆積→有",
    "ディスコース類型":
        "规约性话语 / 基础设施话语 / 商业话语 / 交际性话语 / 判读不能 / 其他（Scollon & Scollon 2003）。"
        "判定順: ①交际性(Transgressive:涂鸦・未授権貼付・私的メモ) → ②规约性(行動を規制:禁止・警告・指示) "
        "→ ③基础设施(施設の身元表示:門牌・路牌・電柱番号・楼層指示) → ④商业(販売・広告・招徕)。"
        "内容が読めなければ判读不能",
    "製作品質":
        "专业印刷 / 半专门 / 手作。工芸水準のみを見る（内容は見ない）。"
        "专业印刷=アルミ看板・発光文字・チェーン統一店招；"
        "半专门=家庭用プリンタ印刷・通販簡易横断幕・AI生成ポスター（機械は介在するが専門デザイン/業者なし）；"
        "手作=手書き・手描き・自作紙",
    "備考":
        "この写真からの新規観察のみ（自由記述）。分類の迷い・例外・境界判断の理由は「【判断】」接頭辞、"
        "同一載体上の同款重複数は「【数量】×N」。書くことが無ければ空文字列",
}


def build_prompt(fields: list[str]) -> str:
    """v6 対象外の旧字段（名称/文字体系/空間階層/設置主体）が渡されても
    AI には出さない（AI_FIELDS = v6 の 13 維度が正）。"""
    requested = fields or AI_FIELDS
    use = [f for f in requested if f in AI_FIELDS]
    fallback = '判定結果（不確実なら \\"\\"）'
    body = ",\n".join(
        f'  "{f}": "{_FIELD_GUIDE.get(f, fallback)}"'
        for f in (use or AI_FIELDS)
    )
    return (
        "この写真の看板・サイン・貼り紙を分析してください。\n"
        "各値は説明文でなく判定結果そのもの。判定できない字段は空文字列 \"\" にしてください。\n"
        "以下のJSON形式のみで回答してください。前置き・説明・マークダウンは不要です：\n\n"
        "{\n" + body + "\n}"
    )


# ── 画像（§9 のAI推奨: 最大辺1024 / quality75） ─────────────────────

def image_to_base64(photo_bytes: bytes) -> str:
    """縮小 JPEG の base64。デコード不能なら原样 base64（アプリと同じ回退）。"""
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(photo_bytes))
        im = im.convert("RGB")
        long_side = max(im.size)
        if long_side > 1024:
            scale = 1024 / long_side
            im = im.resize(
                (max(1, round(im.width * scale)), max(1, round(im.height * scale))))
        out = io.BytesIO()
        im.save(out, format="JPEG", quality=75)
        return base64.b64encode(out.getvalue()).decode("ascii")
    except Exception:
        return base64.b64encode(photo_bytes).decode("ascii")


# ── プロバイダ呼び出し（モデル・端点はアプリ ai.dart と同一） ────────

CLAUDE_MODEL = "claude-haiku-4-5-20251001"
GEMINI_MODEL = "gemini-2.5-flash"
_TIMEOUT = 60.0  # 秒。超過は例外 → ジョブのレコード単位エラーに載る


def strip_json(text: str) -> dict:
    """モデル出力から最初の JSON オブジェクトを取り出す。"""
    m = re.search(r"\{.*\}", text.strip(), re.DOTALL)
    if m is None:
        return {}
    try:
        v = json.loads(m.group(0))
        return v if isinstance(v, dict) else {}
    except ValueError:
        return {}


def _judge_claude(b64: str, fields: list[str], key: str) -> dict:
    r = httpx.post(
        "https://api.anthropic.com/v1/messages",
        headers={
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": CLAUDE_MODEL,
            "max_tokens": 1500,  # v6 は 13 字段＋備考の自由記述 — 1000 だと切れ得る
            "system": _SYSTEM_PROMPT,
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "image",
                     "source": {"type": "base64", "media_type": "image/jpeg",
                                "data": b64}},
                    {"type": "text", "text": build_prompt(fields)},
                ],
            }],
        },
        timeout=_TIMEOUT,
    )
    if r.status_code != 200:
        raise RuntimeError(f"Claude API {r.status_code}: {r.text[:300]}")
    blocks = r.json().get("content", [])
    # type=="text" の最初のブロック（将来 thinking が先頭に来ても壊れない）。
    text = next((b.get("text", "") for b in blocks if b.get("type") == "text"), "")
    return strip_json(str(text))


def _judge_gemini(b64: str, fields: list[str], key: str) -> dict:
    r = httpx.post(
        "https://generativelanguage.googleapis.com/v1beta/"
        f"models/{GEMINI_MODEL}:generateContent",
        headers={
            "content-type": "application/json",
            # key は URL クエリでなくヘッダで送る（プロキシ/アクセスログに残さない）。
            "x-goog-api-key": key,
        },
        json={
            "contents": [{
                "parts": [
                    {"text": f"{_SYSTEM_PROMPT}\n\n{build_prompt(fields)}"},
                    {"inline_data": {"mime_type": "image/jpeg", "data": b64}},
                ],
            }],
        },
        timeout=_TIMEOUT,
    )
    if r.status_code != 200:
        raise RuntimeError(f"Gemini API {r.status_code}: {r.text[:300]}")
    try:
        text = r.json()["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError):
        return {}
    return strip_json(str(text))


def judge_photo(provider: str, photo_path: Path, fields: list[str],
                api_key: str) -> dict:
    """写真 1 枚を判定して下書き dict を返す（ai_jobs から呼ばれる。
    テストはこの関数を monkeypatch して実 API 呼び出しを避ける）。"""
    b64 = image_to_base64(photo_path.read_bytes())
    if provider == "gemini":
        return _judge_gemini(b64, fields, api_key)
    return _judge_claude(b64, fields, api_key)


# ── AI 下書きの併合（record_ops.dart mergeAiDraft の移植） ───────────
#
# 規則1: 既存内容は絶対に削除・上書きしない。
#   - 備考: 既存があれば「既存 新規」の形で後ろに追記する
#     （定義表 r18「本数据库之前已经有的内容，不要覆盖！」）。
#   - 複数選択字段（主要言語等）: 既存値との和集合（新値のみ後ろへ追加）。
#   - 単一選択字段: 既存が非空なら AI 値は書かない（人の入力を守る）。
# 規則2: 不確実は空欄のまま。AI が "" / null を返した字段は一切書かない。

def _clean_ai_value(v) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def merge_ai_draft(data: dict, draft: dict, multi_fields: set[str]) -> int:
    """下書き draft を記録の全字段 dict（data_json）へ併合し、
    実際に書き込んだ字段数を返す。既存データは消えない・変わらない。"""
    changed = 0
    for field, raw in draft.items():
        value = _clean_ai_value(raw)
        if value is None:
            continue  # 規則2: 不確実（空）は書かない

        existing = str(data.get(field, "") or "").strip()

        if field == "備考":
            # 規則1: 追記のみ。同文が既に含まれていれば重複追記しない。
            if value == "—":
                continue  # 「無し」相当は備考に書かない
            if not existing:
                data[field] = value
                changed += 1
            elif value not in existing:
                data[field] = f"{existing} {value}"
                changed += 1
            continue

        if field in multi_fields:
            # 和集合: 既存の選択値を保ち、新値だけ後ろへ追加（'—' は「無し」マーカー）。
            current = split_multi(existing)
            incoming = split_multi(value)
            if not current:
                # existing=='—'（明示的な「無し」）は人の判断 — 上書きしない。
                if not existing:
                    data[field] = value
                    changed += 1
                continue
            added = [v for v in incoming if v not in current]
            if added:
                data[field] = "/".join([*current, *added])
                changed += 1
            continue

        # 単一選択・自由記述: 空欄のみ埋める（既存の人力/過去値は上書きしない）。
        if not existing:
            data[field] = value
            changed += 1
    return changed
