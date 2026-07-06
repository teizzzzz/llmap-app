import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getAiStatus, getRecords } from '../api/client';
import type { AiStatus, RecordsQuery } from '../api/types';
import useFilterOptions from '../hooks/useFilterOptions';

// AI タスク種別（key は内部値。表示は ai.tasks.<key> の i18n キーで引く）。
// すべて scaffold（実 API 呼び出しは backend 設定まで無効）。
const TASKS = ['lang', 'ocr', 'fields', 'translate', 'dup', 'privacy'];

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review', 'reviewed', 'verified', 'rejected'];

export default function AiProcessingPage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<RecordsQuery>({ dataStatus: 'raw' });
  const [total, setTotal] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ai, setAi] = useState<AiStatus | null>(null);
  const { schema, datasets, areas } = useFilterOptions();

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

  const patch = (p: Partial<RecordsQuery>) => setFilters((f) => ({ ...f, ...p }));
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

  // backend からのメッセージ（英文の可能性あり）はそのまま出し、
  // 未取得時のみ翻訳済みの既定文を使う。
  const disabledReason = ai?.message ?? t('ai.notConfigured');

  return (
    <>
      <div className="page-header">
        <h1>{t('ai.title')}</h1>
        <p>
          {t('ai.subtitle')}{' '}
          <span className="muted">{t('ai.note')}</span>
        </p>
      </div>

      {/* 安全説明（必須表示） */}
      <div className="warn-box" style={{ marginBottom: 14 }}>
        <strong>{t('ai.safetyTitle')}</strong>
        <ul>
          <li>{t('ai.safety1')}</li>
          <li>{t('ai.safety2')}</li>
          <li>
            {t('ai.safety3')}{' '}
            ({t('ai.safety3Planned')}: <code>_ai.主要言語</code>,{' '}
            <code>_ai.文字体系</code>, <code>_ai.confidence</code>,{' '}
            <code>_ai.provider</code>, <code>_ai.updatedAt</code>)
          </li>
          <li>{t('ai.safety4')}</li>
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
        {sel(t('filters.gps'), filters.hasGps === undefined ? '' : String(filters.hasGps),
          yesNo,
          (v) => patch({ hasGps: v === '' ? undefined : v === 'true' }))}
        <span className="spacer" />
        <span className="muted total">
          {total != null ? t('ai.match', { n: total }) : ''}
        </span>
        <button className="btn" onClick={() => setFilters({})}>{t('common.clearFilters')}</button>
        <button className="btn" onClick={fetchTotal}>{t('common.refresh')}</button>
      </div>

      {error && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <strong>{t('ai.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {/* 2. Task types */}
      <h3 className="detail-section">{t('ai.taskType')}</h3>
      <div className="format-grid">
        {TASKS.map((k) => (
          <div key={k} className="card format-card disabled">
            <div className="format-head">
              <strong>{t(`ai.tasks.${k}.title`)}</strong>
              <span className="badge" style={{ color: '#6f6a61', borderColor: '#6f6a6155', background: '#6f6a6114' }}>
                {t('common.comingSoon')}
              </span>
            </div>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>
              {t(`ai.tasks.${k}.desc`)}
            </p>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 11.5 }}>
              {t('ai.requiresBackend')}
            </p>
          </div>
        ))}
      </div>

      {/* 3. Dry run / Run（backend 未設定のため常に無効） */}
      <h3 className="detail-section" style={{ marginTop: 20 }}>{t('ai.previewRun')}</h3>
      <div className="card export-summary">
        <div>
          <div className="label muted">
            {t('ai.selectedBatch', { n: total ?? '—' })}
          </div>
          <div className="muted" style={{ marginTop: 4, fontSize: 12.5 }}>
            {ai
              ? `${disabledReason} (${t('ai.providers')}: ${
                  ai.providers.length ? ai.providers.join(', ') : t('common.none')
                })`
              : t('ai.checking')}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" disabled title={disabledReason}>{t('ai.dryRun')}</button>
          <button className="btn primary" disabled title={disabledReason}>
            {t('ai.runBatch')}
          </button>
        </div>
      </div>
    </>
  );
}
