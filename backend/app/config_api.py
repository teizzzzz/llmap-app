"""
アプリ設定 API（settings.json の読み書き）。
- GET /config : 現在の設定＋実効値（導出先はフォールバック後のパスも返す）
- PUT /config : 設定を更新。現状は exportDir のみ。
  exportDir は絶対パス必須・作成/書き込み検証つき。null/空文字で既定に戻す。

導出ファイルは従来 data_dir/exports（桌面版では C: の %APPDATA%\\LLMap）へ
生成されていた。大きな zip で C 盘を圧迫しないよう、任意のドライブ/目录を
指定できるようにする。設定は data_dir/settings.json に永続化される。
"""
from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, Body, HTTPException

from .database import (
    default_exports_dir, exports_dir, load_settings, save_settings,
)

router = APIRouter(tags=["config"])


_AI_PROVIDERS = ("claude", "gemini")
_AI_KEY_FIELDS = ("claudeApiKey", "geminiApiKey")


def _ai_model_options() -> dict[str, tuple[str, ...]]:
    from .ai_engine import CLAUDE_MODELS, GEMINI_MODELS
    return {"claudeModel": CLAUDE_MODELS, "geminiModel": GEMINI_MODELS}


def _key_hint(v: str) -> str:
    """キーの識別用ヒント（末尾4桁のみ）。CORS が全開のため GET で完全な
    キーを返さない — どの網站からでも fetch で読めてしまう。書き込みは PUT のみ。"""
    v = v.strip()
    return f"…{v[-4:]}" if len(v) >= 8 else ("設定済み" if v else "")


def _config_payload() -> dict:
    settings = load_settings()
    payload = {
        "exportDir": settings.get("exportDir") or None,
        "effectiveExportDir": str(exports_dir()),
        "defaultExportDir": str(default_exports_dir()),
        "aiProvider": settings.get("aiProvider") or None,
    }
    for f in _AI_KEY_FIELDS:
        v = (settings.get(f) or "").strip()
        payload[f + "Set"] = bool(v)
        payload[f + "Hint"] = _key_hint(v)
    # モデル: 未設定は既定（選択肢の先頭）を返す。不正保存値も既定へ丸める。
    for f, options in _ai_model_options().items():
        v = settings.get(f) or ""
        payload[f] = v if v in options else options[0]
    return payload


@router.get("/config")
def get_config():
    return _config_payload()


def _validate_export_dir(raw: str) -> Path:
    """絶対パス・作成可能・書き込み可能を検証し、正規化パスを返す。"""
    p = Path(raw).expanduser()
    if not p.is_absolute():
        raise HTTPException(400, f"絶対パスを指定してください: {raw}")
    try:
        p.mkdir(parents=True, exist_ok=True)
        # 書き込み探査（作れなければ即時に分かるように。残骸は残さない）
        probe = p / f".llmap-write-test-{uuid.uuid4().hex[:8]}"
        probe.write_bytes(b"")
        probe.unlink()
    except OSError as e:
        raise HTTPException(400, f"目录に書き込めません: {p}（{e}）")
    return p


@router.put("/config")
def put_config(payload: dict = Body(...)):
    settings = load_settings()

    if "exportDir" in payload:
        raw = payload["exportDir"]
        if raw in (None, ""):
            settings.pop("exportDir", None)  # 既定（data_dir/exports）へ戻す
        else:
            if not isinstance(raw, str):
                raise HTTPException(400, "exportDir は文字列か null で指定してください")
            settings["exportDir"] = str(_validate_export_dir(raw))

    if "aiProvider" in payload:
        raw = payload["aiProvider"]
        if raw in (None, ""):
            settings.pop("aiProvider", None)
        elif raw in _AI_PROVIDERS:
            settings["aiProvider"] = raw
        else:
            raise HTTPException(
                400, f"不正な aiProvider です（{'/'.join(_AI_PROVIDERS)}）: {raw}")

    for f in _AI_KEY_FIELDS:
        if f not in payload:
            continue
        raw = payload[f]
        if raw in (None, ""):
            settings.pop(f, None)  # 明示的にキーを消す
        elif isinstance(raw, str):
            settings[f] = raw.strip()
        else:
            raise HTTPException(400, f"{f} は文字列か null で指定してください")

    model_options = _ai_model_options()
    for f, options in model_options.items():
        if f not in payload:
            continue
        raw = payload[f]
        if raw in (None, ""):
            settings.pop(f, None)  # 既定モデルへ戻す
        elif raw in options:
            settings[f] = raw
        else:
            raise HTTPException(
                400, f"不正な {f} です（許容値: {list(options)}）: {raw}")

    known = {"exportDir", "aiProvider", *_AI_KEY_FIELDS, *model_options}
    unknown = [k for k in payload if k not in known]
    if unknown:
        raise HTTPException(400, f"未知の設定キーです: {unknown}")

    save_settings(settings)
    return _config_payload()
