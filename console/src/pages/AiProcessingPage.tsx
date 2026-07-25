import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  ApiError, aiPreview, cancelAiJob, getAiJob, getAiStatus, getRecords,
  startAiJob,
} from '../api/client';
import type {
  AiJobStatus, AiLogEntry, AiPreview, AiStatus, RecordsQuery,
} from '../api/types';
import useFilterOptions from '../hooks/useFilterOptions';

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review', 'reviewed', 'verified', 'rejected'];

/** バッチ AI ジョブ 1 本の管理（進捗ポーリング・取消・実時ログの増分蓄積）。 */
function useAiJob() {
  const [job, setJob] = useState<AiJobStatus | null>(null);
  const [logs, setLogs] = useState<AiLogEntry[]>([]);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastSeq = useRef(-1);

  const stopPolling = useCallback(() => {
    if (timer.current != null) {
      clearInterval(timer.current);
      timer.current = null;
    }
  }, []);
  useEffect(() => stopPolling, [stopPolling]);

  const start = async (filters: RecordsQuery) => {
    setStarting(true);
    setError(null);
    setJob(null);
    setLogs([]);
    lastSeq.current = -1;
    try {
      const { jobId } = await startAiJob(filters);
      timer.current = setInterval(async () => {
        try {
          const st = await getAiJob(jobId, lastSeq.current);
          setJob(st);
          if (st.logs.length > 0) {
            lastSeq.current = st.lastSeq;
            // 表示は直近 1000 行に抑える（DOM を無限に増やさない）
            setLogs((prev) => [...prev, ...st.logs].slice(-1000));
          }
          if (st.status !== 'running') stopPolling();
        } catch {
          stopPolling();
        }
      }, 700);
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setStarting(false);
    }
  };

  const cancel = async () => {
    if (job && job.status === 'running') await cancelAiJob(job.id);
  };

  return { job, logs, starting, error, start, cancel };
}

export default function AiProcessingPage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<RecordsQuery>({ dataStatus: 'raw' });
  const [total, setTotal] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ai, setAi] = useState<AiStatus | null>(null);
  const [preview, setPreview] = useState<AiPreview | null>(null);
  const [previewing, setPreviewing] = useState(false);
  const { schema, datasets, areas } = useFilterOptions();
  const jc = useAiJob();

  useEffect(() => {
    getAiStatus().then(setAi).catch(() => {});
  }, []);

  const fetchTotal = useCallback(() => {
    setError(null);
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => setTotal(r.total))
      .catch((e: unknown) => {
        setTotal(null);
        setError(e instanceof ApiError ? e.message : String(e));
      });
  }, [filters]);
  useEffect(fetchTotal, [fetchTotal]);

  const patch = (p: Partial<RecordsQuery>) => {
    setPreview(null);
    setFilters((f) => ({ ...f, ...p }));
  };

  const doPreview = async () => {
    setPreviewing(true);
    setError(null);
    try {
      setPreview(await aiPreview(filters));
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setPreviewing(false);
    }
  };

  const doRun = async () => {
    // 実 API 呼び出し = 課金。件数とプロバイダを見せて確認してから走らせる。
    const n = preview?.withPhoto ?? total ?? 0;
    const provider = ai?.provider ?? 'claude';
    const model = ai?.models?.[provider] ?? provider;
    if (!window.confirm(t('ai.confirmRun', { n, model }))) return;
    await jc.start(filters);
  };

  const sel = (
    label: string,
    value: string,
    options: { value: string; label: string }[],
    onChange: (v: string) => void,
  ) => (
    <label className="filter-field" key={label}>
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">{t('common.all')}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </label>
  );
  const raw = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  const translated = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));
  const yesNo = [
    { value: 'true', label: t('common.yes') },
    { value: 'false', label: t('common.no') },
  ];

  const report = jc.job?.report;

  // 実時ログ: 追記のたびに末尾へ自動スクロール。
  const logBox = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    logBox.current?.scrollTo({ top: logBox.current.scrollHeight });
  }, [jc.logs]);

  /** ログ 1 行の表示文（event は内部値 — 文言はここで i18n）。 */
  const logLine = (e: AiLogEntry): { text: string; color?: string } => {
    switch (e.event) {
      case 'jobStart':
        return { text: t('ai.log.jobStart', { model: e.data.model, total: e.data.total }) };
      case 'changed':
        return { text: `✓ ${e.signId} — ${t('ai.log.changed', { n: e.data.n })}`, color: '#1d7a4f' };
      case 'unchanged':
        return { text: `– ${e.signId} — ${t('ai.log.unchanged')}`, color: '#6f6a61' };
      case 'skipped':
        return { text: `⏭ ${e.signId} — ${t('ai.log.skipped')}`, color: '#6f6a61' };
      case 'error':
        return { text: `✗ ${e.signId} — ${e.data.message}`, color: '#b3261e' };
      case 'abort':
        return { text: `✗ ${t('ai.log.abort', { message: e.data.message })}`, color: '#b3261e' };
      case 'cancelled':
        return { text: t('ai.log.cancelled'), color: '#6f6a61' };
      case 'done':
        return {
          text: t('ai.log.done', {
            changed: e.data.changed, unchanged: e.data.unchanged,
            skipped: e.data.skipped, errors: e.data.errors,
          }),
          color: '#1d7a4f',
        };
      default:
        return { text: `${e.event} ${e.signId}` };
    }
  };

  return (
    <>
      <div className="page-header">
        <h1>{t('ai.title')}</h1>
        <p>
          {t('ai.subtitle')}{' '}
          <span className="muted">{t('ai.note')}</span>
        </p>
      </div>

      {/* v6 の 2 大規則（実装済みの併合動作の説明 — 必須表示） */}
      <div className="warn-box" style={{ marginBottom: 14 }}>
        <strong>{t('ai.safetyTitle')}</strong>
        <ul>
          <li>{t('ai.rule1')}</li>
          <li>{t('ai.rule2')}</li>
          <li>{t('ai.rule3')}</li>
          <li>{t('ai.rule4')}</li>
        </ul>
      </div>

      {/* 1. Batch selection */}
      <h3 className="detail-section">{t('ai.batchSelection')}</h3>
      <div className="card filters-bar">
        {sel(t('filters.status'), filters.dataStatus ?? '', translated(DATA_STATUSES),
          (v) => patch({ dataStatus: v || undefined }))}
        {sel(t('filters.mode'), filters.entryMode ?? '', translated(ENTRY_MODES),
          (v) => patch({ entryMode: v || undefined }))}
        {sel(t('filters.language'), filters.mainLanguage ?? '',
          raw(schema?.enums['主要言語'] ?? []),
          (v) => patch({ mainLanguage: v || undefined }))}
        {sel(t('filters.area'), filters.areaCode ?? '', raw(areas),
          (v) => patch({ areaCode: v || undefined }))}
        <label className="filter-field">
          <span>{t('filters.dataset')}</span>
          <select
            value={filters.datasetId != null ? String(filters.datasetId) : ''}
            onChange={(e) =>
              patch({ datasetId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">{t('common.all')}</option>
            {datasets.map((d) => (
              <option key={d.id} value={d.id}>{`#${d.id} ${d.name}`}</option>
            ))}
          </select>
        </label>
        {sel(t('filters.photo'), filters.hasPhoto === undefined ? '' : String(filters.hasPhoto),
          yesNo,
          (v) => patch({ hasPhoto: v === '' ? undefined : v === 'true' }))}
        <span className="spacer" />
        <span className="muted total">
          {total != null ? t('ai.match', { n: total }) : ''}
        </span>
        <button className="btn" onClick={() => { setPreview(null); setFilters({}); }}>
          {t('common.clearFilters')}
        </button>
        <button className="btn" onClick={fetchTotal}>{t('common.refresh')}</button>
      </div>

      {error && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <strong>{t('ai.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {/* 2. Task（v6 の 13 維度起草 — 唯一の実タスク） */}
      <h3 className="detail-section">{t('ai.taskType')}</h3>
      <div className="card">
        <div className="format-head">
          <strong>{t('ai.task.title')}</strong>
          {ai && (
            <span className="badge" style={ai.enabled
              ? { color: '#1d7a4f', borderColor: '#1d7a4f55', background: '#1d7a4f14' }
              : { color: '#6f6a61', borderColor: '#6f6a6155', background: '#6f6a6114' }}>
              {ai.enabled
                ? `${ai.provider} · ${ai.models?.[ai.provider] ?? ''}`
                : t('ai.disabledBadge')}
            </span>
          )}
        </div>
        <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>
          {t('ai.task.desc')}
        </p>
        {ai && !ai.enabled && (
          <p className="muted" style={{ margin: '8px 0 0', fontSize: 12.5 }}>
            {ai.message} {t('ai.goSettings')}
          </p>
        )}
      </div>

      {/* 3. Preview / Run */}
      <h3 className="detail-section" style={{ marginTop: 20 }}>{t('ai.previewRun')}</h3>
      <div className="card export-summary">
        <div>
          <div className="label muted">
            {t('ai.selectedBatch', { n: total ?? '—' })}
          </div>
          {preview && (
            <div className="muted" style={{ marginTop: 4, fontSize: 12.5 }}>
              {t('ai.previewResult', {
                withPhoto: preview.withPhoto,
                noPhoto: preview.withoutPhoto + preview.missingPhotoFile,
              })}{' '}
              {Object.entries(preview.byStatus)
                .map(([k, v]) => `${t(`status.${k}`, { defaultValue: k })}: ${v}`)
                .join(' · ')}
            </div>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" disabled={previewing} onClick={doPreview}>
            {t('ai.dryRun')}
          </button>
          <button
            className="btn primary"
            disabled={!ai?.enabled || jc.starting || jc.job?.status === 'running'}
            title={ai?.enabled ? undefined : (ai?.message ?? t('ai.checking'))}
            onClick={doRun}
          >
            {t('ai.runBatch')}
          </button>
        </div>
      </div>

      {/* ジョブ進捗・結果 */}
      {jc.error && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <div className="hint">{jc.error}</div>
        </div>
      )}
      {jc.job?.status === 'running' && (
        <div className="muted" style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
          <span>{t('ai.progress', { done: jc.job.done, total: jc.job.total })}</span>
          <button className="btn" onClick={jc.cancel}>{t('common.cancel')}</button>
        </div>
      )}
      {jc.job?.status === 'done' && report && (
        <div className="ok-box" style={{ marginTop: 10 }}>
          {t('ai.doneSummary', {
            changed: report.changedRecords ?? 0,
            fields: report.changedFieldTotal ?? 0,
            unchanged: report.unchangedRecords ?? 0,
            skipped: report.skippedNoPhoto ?? 0,
            errors: report.errorCount ?? 0,
          })}
        </div>
      )}
      {jc.job?.status === 'cancelled' && (
        <div className="muted" style={{ marginTop: 10 }}>
          {t('ai.cancelledNote', { done: jc.job.done })}
        </div>
      )}
      {jc.job?.status === 'error' && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <strong>{t('ai.failed')}</strong>
          <div className="hint">{jc.job.error}</div>
        </div>
      )}
      {/* 実時ログ（増分ポーリング・自動スクロール） */}
      {jc.logs.length > 0 && (
        <div className="card" style={{ marginTop: 10, padding: 10 }}>
          <strong style={{ fontSize: 13 }}>{t('ai.log.title')}</strong>
          <div
            ref={logBox}
            style={{
              marginTop: 6, maxHeight: 260, overflowY: 'auto',
              fontFamily: 'ui-monospace, Consolas, monospace', fontSize: 12,
              lineHeight: 1.7, whiteSpace: 'pre-wrap', wordBreak: 'break-all',
            }}
          >
            {jc.logs.map((e) => {
              const { text, color } = logLine(e);
              return (
                <div key={e.seq} style={color ? { color } : undefined}>
                  <span className="muted">[{e.time}]</span> {text}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {jc.job && jc.job.errors.length > 0 && (
        <div className="card" style={{ marginTop: 10 }}>
          <strong style={{ fontSize: 13 }}>{t('ai.errorsTitle')}</strong>
          <ul className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>
            {jc.job.errors.map((e) => (
              <li key={e.signId}><code>{e.signId}</code> — {e.message}</li>
            ))}
          </ul>
        </div>
      )}
    </>
  );
}
