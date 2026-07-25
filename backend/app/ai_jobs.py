"""
バッチ AI ジョブ（Step 18）: 筛选に一致する記録の裁切写真を Claude/Gemini で
判定し、v6 の併合規則（追記のみ・空欄のみ・不確実は書かない）で下書きを併合する。
導出ジョブ（export_jobs）と同じ「後台スレッド＋進捗ポーリング＋取消」の型。

安全設計:
- 記録ごとに独立コミット — 取消・途中エラーでも完了分は残る（やり直しても
  併合規則が冪等に守るので二重適用の害はない）。
- 連続失敗 3 件で中止 — キー無効・ネットワーク断で全件を空振りしない。
- 状態昇格は pending→ai のみ（human-reviewed / final を降格させない）。

API:
  GET  /ai/status                      → 設定状態（キー有無・選択プロバイダ）
  POST /ai/preview   {filters...}      → 対象件数の事前集計（AI 呼び出し無し）
  POST /ai/jobs      {filters..., provider?} → {jobId}
  GET  /ai/jobs/{id}                   → 進捗・結果
  POST /ai/jobs/{id}/cancel
"""
from __future__ import annotations

import json
import threading
import uuid
from dataclasses import dataclass, field
from datetime import datetime

from fastapi import APIRouter, Body, HTTPException
from sqlmodel import Session

from . import ai_engine
from .database import get_engine, load_settings, photos_dir
from .db_models import SignRecord
from .export_jobs import _filters_kwargs, _load_records
from .schema import AI_FIELDS, DATA_STATUS_MAP, MULTI_FIELDS

router = APIRouter(tags=["ai"])

PROVIDERS = ("claude", "gemini")
_KEY_OF = {"claude": "claudeApiKey", "gemini": "geminiApiKey"}
_MODEL_KEY_OF = {"claude": "claudeModel", "gemini": "geminiModel"}
# キー無効等で全件を空振りしないための中止閾値（連続失敗数）。
_ABORT_AFTER = 3


def _provider_state() -> tuple[str, list[str], dict]:
    """(選択プロバイダ, キー設定済み一覧, settings) を返す。"""
    settings = load_settings()
    configured = [p for p in PROVIDERS if (settings.get(_KEY_OF[p]) or "").strip()]
    provider = settings.get("aiProvider") or ""
    if provider not in PROVIDERS:
        provider = configured[0] if configured else "claude"
    return provider, configured, settings


def _model_of(provider: str, settings: dict) -> str:
    """設定されたモデル（未設定・不正値は既定へ）。"""
    options = ai_engine.CLAUDE_MODELS if provider == "claude" \
        else ai_engine.GEMINI_MODELS
    configured = settings.get(_MODEL_KEY_OF.get(provider, ""), "")
    return configured if configured in options else options[0]


@router.get("/ai/status")
def ai_status():
    provider, configured, settings = _provider_state()
    enabled = provider in configured
    if enabled:
        message = ""
    elif configured:
        message = f"選択中のプロバイダ {provider} の API キーが未設定です。"
    else:
        message = "AI プロバイダの API キーが未設定です（設定 → AI で入力）。"
    return {
        "enabled": enabled,
        "provider": provider,
        "providers": configured,
        "message": message,
        # 選択中のモデルと選択肢（Console の設定 UI・実行確認ダイアログ用）
        "models": {"claude": _model_of("claude", settings),
                   "gemini": _model_of("gemini", settings)},
        "modelOptions": {"claude": list(ai_engine.CLAUDE_MODELS),
                         "gemini": list(ai_engine.GEMINI_MODELS)},
    }


@router.post("/ai/preview")
def ai_preview(payload: dict = Body(default={})):
    """対象の事前集計のみ（AI 呼び出し・書き込みは一切しない）。"""
    filters = _filters_kwargs(payload)
    with Session(get_engine()) as session:
        records = _load_records(session, filters)
        with_photo = 0
        missing_file = 0
        by_status: dict[str, int] = {}
        for rec in records:
            by_status[rec.status or ""] = by_status.get(rec.status or "", 0) + 1
            if not rec.photo_file_name:
                continue
            if (photos_dir() / rec.photo_file_name).is_file():
                with_photo += 1
            else:
                missing_file += 1
    return {
        "total": len(records),
        "withPhoto": with_photo,
        "withoutPhoto": len(records) - with_photo - missing_file,
        "missingPhotoFile": missing_file,
        "byStatus": by_status,
    }


@dataclass
class AiJob:
    id: str
    provider: str
    model: str = ""
    status: str = "running"  # running | done | error | cancelled
    done: int = 0
    total: int = 0
    error: str = ""
    report: dict = field(default_factory=dict)
    errors: list = field(default_factory=list)  # [{signId, message}] 先頭20件
    # 実時ログ（レコードごとの結果）。seq 単調増加 — Console は afterSeq で増分取得。
    logs: list = field(default_factory=list)
    log_seq: int = 0
    cancel_event: threading.Event = field(default_factory=threading.Event)


_LOG_CAP = 5000  # 超巨大バッチでもメモリを暴れさせない（古い行から捨てる）


def _log(job: AiJob, event: str, sign_id: str = "", **data) -> None:
    """構造化ログ 1 行。文言は持たず Console 側で i18n する。"""
    job.log_seq += 1
    job.logs.append({
        "seq": job.log_seq,
        "time": datetime.now().strftime("%H:%M:%S"),
        "event": event,
        "signId": sign_id,
        "data": data,
    })
    if len(job.logs) > _LOG_CAP:
        del job.logs[: len(job.logs) - _LOG_CAP]


_JOBS: dict[str, AiJob] = {}
_JOBS_LOCK = threading.Lock()


class _Cancelled(Exception):
    pass


def _apply_draft(rec: SignRecord, draft: dict) -> int:
    """下書きを記録へ併合し核心列を同期する。書いた字段数を返す（0 なら不変）。"""
    # AI 対象外キーの混入（モデルの脱線）はここで落とす。
    draft = {k: v for k, v in draft.items() if k in AI_FIELDS}
    data = json.loads(rec.data_json)
    changed = ai_engine.merge_ai_draft(data, draft, set(MULTI_FIELDS))
    if changed == 0:
        return 0
    # 状態昇格は pending→ai のみ（人の校閲状態を AI 再実行で降格させない）。
    if rec.status == "pending":
        data["_status"] = "ai"
        data["DataStatus"] = DATA_STATUS_MAP["ai"]
    rec.status = data.get("_status", rec.status)
    rec.data_status = data.get("DataStatus", rec.data_status)
    rec.main_language = data.get("主要言語", rec.main_language)
    rec.sub_language = data.get("補助言語", rec.sub_language)
    rec.data_json = json.dumps(data, ensure_ascii=False)
    rec.updated_at = datetime.now()
    return changed


def _run_batch(job: AiJob, filters: dict, api_key: str) -> None:
    changed_records = 0
    changed_fields = 0
    unchanged = 0
    skipped_no_photo = 0
    consecutive_errors = 0

    with Session(get_engine()) as session:
        records = _load_records(session, filters)
        job.total = len(records)
        _log(job, "jobStart", model=job.model, provider=job.provider,
             total=job.total)
        for rec in records:
            if job.cancel_event.is_set():
                raise _Cancelled()
            job.done += 1

            path = photos_dir() / rec.photo_file_name \
                if rec.photo_file_name else None
            if path is None or not path.is_file():
                skipped_no_photo += 1
                _log(job, "skipped", rec.sign_id)
                continue

            try:
                draft = ai_engine.judge_photo(
                    job.provider, path, AI_FIELDS, api_key, job.model)
                consecutive_errors = 0
            except Exception as e:
                consecutive_errors += 1
                if len(job.errors) < 20:
                    job.errors.append(
                        {"signId": rec.sign_id, "message": str(e)[:300]})
                _log(job, "error", rec.sign_id, message=str(e)[:300])
                if consecutive_errors >= _ABORT_AFTER:
                    raise RuntimeError(
                        f"連続 {_ABORT_AFTER} 件失敗のため中止しました"
                        f"（キー・ネットワークを確認してください）: {e}")
                continue

            n = _apply_draft(rec, draft)
            if n > 0:
                session.add(rec)
                session.commit()  # 記録ごとに確定 — 取消/中断でも完了分は残る
                changed_records += 1
                changed_fields += n
                _log(job, "changed", rec.sign_id, n=n)
            else:
                unchanged += 1
                _log(job, "unchanged", rec.sign_id)

    _log(job, "done", changed=changed_records, unchanged=unchanged,
         skipped=skipped_no_photo, errors=len(job.errors))
    job.report = {
        "recordCount": job.total,
        "changedRecords": changed_records,
        "changedFieldTotal": changed_fields,
        "unchangedRecords": unchanged,
        "skippedNoPhoto": skipped_no_photo,
        "errorCount": len(job.errors),
        "provider": job.provider,
        "model": job.model,
    }


@router.post("/ai/jobs")
def start_ai_job(payload: dict = Body(default={})):
    provider, configured, settings = _provider_state()
    if payload.get("provider"):
        provider = str(payload["provider"])
        if provider not in PROVIDERS:
            raise HTTPException(400, f"不正な provider: {provider}")
    api_key = (settings.get(_KEY_OF.get(provider, "")) or "").strip()
    if not api_key:
        raise HTTPException(
            400, f"{provider} の API キーが未設定です（設定 → AI で入力）。")

    filters = _filters_kwargs(payload)
    job = AiJob(id=uuid.uuid4().hex[:12], provider=provider,
                model=_model_of(provider, settings))
    with _JOBS_LOCK:
        _JOBS[job.id] = job

    def run():
        try:
            _run_batch(job, filters, api_key)
            if job.status == "running":
                job.status = "done"
        except _Cancelled:
            job.status = "cancelled"
            _log(job, "cancelled")
        except Exception as e:  # ジョブはプロセスを巻き込まない
            job.status = "error"
            job.error = str(e)
            _log(job, "abort", message=str(e)[:300])

    threading.Thread(target=run, daemon=True).start()
    return {"jobId": job.id}


def _get_job(job_id: str) -> AiJob:
    job = _JOBS.get(job_id)
    if job is None:
        raise HTTPException(404, f"ジョブが見つかりません: {job_id}")
    return job


@router.get("/ai/jobs/{job_id}")
def ai_job_status(job_id: str, afterSeq: int = -1):
    """進捗＋実時ログ。afterSeq を渡すとそれ以降のログだけ返す（増分ポーリング。
    既定 -1 = 全件）。list(…) でコピーしてからフィルタ — ワーカースレッドが
    追記中でも安全に読める。"""
    job = _get_job(job_id)
    logs = [e for e in list(job.logs) if e["seq"] > afterSeq]
    return {
        "id": job.id,
        "kind": "ai",
        "provider": job.provider,
        "model": job.model,
        "status": job.status,
        "done": job.done,
        "total": job.total,
        "error": job.error,
        "errors": job.errors,
        "report": job.report,
        "logs": logs,
        "lastSeq": job.log_seq,
    }


@router.post("/ai/jobs/{job_id}/cancel")
def ai_job_cancel(job_id: str):
    job = _get_job(job_id)
    if job.status == "running":
        job.cancel_event.set()
    return {"ok": True, "status": job.status}
