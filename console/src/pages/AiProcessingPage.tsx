import { useCallback, useEffect, useState } from 'react';
import { ApiError, getAiStatus, getRecords } from '../api/client';
import type { AiStatus, RecordsQuery } from '../api/types';
import useFilterOptions from '../hooks/useFilterOptions';

// AI タスク種別。すべて scaffold（実 API 呼び出しは backend 設定まで無効）。
const TASKS = [
  { key: 'lang', title: 'Language identification', desc: 'Detect the languages appearing on each sign photo.' },
  { key: 'ocr', title: 'OCR / text extraction', desc: 'Extract visible text from crop photos.' },
  { key: 'fields', title: 'Field suggestion', desc: 'Draft research fields (script, carrier, agent…) from the photo.' },
  { key: 'translate', title: 'Translation', desc: 'Translate extracted text for cross-language analysis.' },
  { key: 'dup', title: 'Duplicate detection', desc: 'Find likely duplicate captures of the same sign.' },
  { key: 'privacy', title: 'Privacy risk detection', desc: 'Flag faces, plates, or personal data before sharing.' },
];

const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review', 'reviewed', 'verified', 'rejected'];

export default function AiProcessingPage() {
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
    options: string[],
    onChange: (v: string) => void,
  ) => (
    <label className="filter-field" key={label}>
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">All</option>
        {options.map((o) => (
          <option key={o} value={o}>{o}</option>
        ))}
      </select>
    </label>
  );

  const disabledReason = ai?.message ?? 'AI backend is not configured.';

  return (
    <>
      <div className="page-header">
        <h1>AI Processing</h1>
        <p>
          Batch AI assistance for large collections.{' '}
          <span className="muted">
            AI suggestions are drafts — they never overwrite human-reviewed fields
            and must be reviewed before becoming research data.
          </span>
        </p>
      </div>

      {/* 安全説明（必須表示） */}
      <div className="warn-box" style={{ marginBottom: 14 }}>
        <strong>Safety rules</strong>
        <ul>
          <li>No AI task will run until an AI backend is configured.</li>
          <li>No API key should be committed to the repository (keys will be read from backend environment variables).</li>
          <li>AI suggestions should be stored separately from human-confirmed fields
            (planned: <code>_ai.主要言語</code>, <code>_ai.文字体系</code>,{' '}
            <code>_ai.confidence</code>, <code>_ai.provider</code>, <code>_ai.updatedAt</code>).</li>
          <li>AI results enter the Review queue as <code>ai_drafted</code>; humans confirm them there.</li>
        </ul>
      </div>

      {/* 1. Batch selection */}
      <h3 className="detail-section">1 · Batch selection</h3>
      <div className="card filters-bar">
        {sel('Status', filters.dataStatus ?? '', DATA_STATUSES,
          (v) => patch({ dataStatus: v || undefined }))}
        {sel('Mode', filters.entryMode ?? '', ENTRY_MODES,
          (v) => patch({ entryMode: v || undefined }))}
        {sel('Language', filters.mainLanguage ?? '', schema?.enums['主要言語'] ?? [],
          (v) => patch({ mainLanguage: v || undefined }))}
        {sel('Area', filters.areaCode ?? '', areas,
          (v) => patch({ areaCode: v || undefined }))}
        <label className="filter-field">
          <span>Dataset</span>
          <select
            value={filters.datasetId != null ? String(filters.datasetId) : ''}
            onChange={(e) =>
              patch({ datasetId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">All</option>
            {datasets.map((d) => (
              <option key={d.id} value={d.id}>{`#${d.id} ${d.name}`}</option>
            ))}
          </select>
        </label>
        {sel('Photo', filters.hasPhoto === undefined ? '' : String(filters.hasPhoto),
          ['true', 'false'],
          (v) => patch({ hasPhoto: v === '' ? undefined : v === 'true' }))}
        {sel('GPS', filters.hasGps === undefined ? '' : String(filters.hasGps),
          ['true', 'false'],
          (v) => patch({ hasGps: v === '' ? undefined : v === 'true' }))}
        <span className="spacer" />
        <span className="muted total">
          {total != null ? `${total} records match` : ''}
        </span>
        <button className="btn" onClick={() => setFilters({})}>Clear filters</button>
        <button className="btn" onClick={fetchTotal}>Refresh</button>
      </div>

      {error && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <strong>Could not load matching records.</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {/* 2. Task types */}
      <h3 className="detail-section">2 · Task type</h3>
      <div className="format-grid">
        {TASKS.map((t) => (
          <div key={t.key} className="card format-card disabled">
            <div className="format-head">
              <strong>{t.title}</strong>
              <span className="badge" style={{ color: '#6f6a61', borderColor: '#6f6a6155', background: '#6f6a6114' }}>
                Coming soon
              </span>
            </div>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>{t.desc}</p>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 11.5 }}>
              Requires AI backend configuration.
            </p>
          </div>
        ))}
      </div>

      {/* 3. Dry run / Run（backend 未設定のため常に無効） */}
      <h3 className="detail-section" style={{ marginTop: 20 }}>3 · Preview / run</h3>
      <div className="card export-summary">
        <div>
          <div className="label muted">
            Selected batch: {total ?? '—'} records · task: none
          </div>
          <div className="muted" style={{ marginTop: 4, fontSize: 12.5 }}>
            {ai
              ? `${disabledReason} (providers: ${ai.providers.length ? ai.providers.join(', ') : 'none'})`
              : 'Checking AI backend status…'}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" disabled title={disabledReason}>Dry run</button>
          <button className="btn primary" disabled title={disabledReason}>
            Run batch
          </button>
        </div>
      </div>
    </>
  );
}
