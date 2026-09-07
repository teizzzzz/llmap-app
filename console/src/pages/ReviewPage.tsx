import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getRecords } from '../api/client';
import type { RecordItem } from '../api/types';
import ReviewQueue from '../components/review/ReviewQueue';
import ReviewWorkspace from '../components/review/ReviewWorkspace';
import useFilterOptions from '../hooks/useFilterOptions';
import { enumLabel } from '../lib/enumLabels';
import { languageFilterValues } from '../lib/languageList';
import { QUEUE_TABS } from '../reviewStatus';

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const QUEUE_PAGE_SIZE = 100;

interface QueueFilters {
  entryMode?: string;
  mainLanguage?: string;
  areaCode?: string;
  datasetId?: number;
}

export default function ReviewPage() {
  const { t } = useTranslation();
  const [tab, setTab] = useState('pending'); // 既定: raw/submitted/ai_drafted(+needs_review)
  const [filters, setFilters] = useState<QueueFilters>({});
  const [items, setItems] = useState<RecordItem[] | null>(null);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const { schema, datasets, areas } = useFilterOptions();

  // 未保存の変更がある間の記録切替を保護する（workspace から通知される）。
  const dirtyRef = useRef(false);
  const confirmLeave = () =>
    !dirtyRef.current || window.confirm(t('review.confirmDiscard'));

  const statuses =
    QUEUE_TABS.find((tb) => tb.key === tab)?.statuses ?? QUEUE_TABS[0].statuses;

  const fetchQueue = useCallback(
    (selectFirst: boolean) => {
      setError(null);
      getRecords({
        ...filters,
        dataStatus: statuses.join(','),
        page: 1,
        pageSize: QUEUE_PAGE_SIZE,
      })
        .then((res) => {
          setItems(res.items);
          setTotal(res.total);
          if (selectFirst) {
            setSelectedId(res.items[0]?.id ?? null);
          }
        })
        .catch((e: unknown) => {
          setItems(null);
          setError(e instanceof ApiError ? e.message : String(e));
        });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [filters, tab],
  );
  useEffect(() => fetchQueue(true), [fetchQueue]);

  /** 現在の記録の「次」を返す（末尾なら前、1件だけなら null）。 */
  const nextIdAfter = (id: number): number | null => {
    const list = items ?? [];
    const i = list.findIndex((r) => r.id === id);
    if (i < 0) return list[0]?.id ?? null;
    return list[i + 1]?.id ?? list[i - 1]?.id ?? null;
  };

  /** workspace の保存/審核動作の成功後: 队列を再取得し、必要なら次へ進む。 */
  const handleActioned = (recordId: number, advance: boolean) => {
    if (advance) setSelectedId(nextIdAfter(recordId));
    fetchQueue(false);
  };

  const skipNext = () => {
    if (selectedId == null || !confirmLeave()) return;
    dirtyRef.current = false;
    setSelectedId(nextIdAfter(selectedId));
  };

  const select = (id: number) => {
    if (id === selectedId || !confirmLeave()) return;
    dirtyRef.current = false;
    setSelectedId(id);
  };

  const patchFilters = (p: Partial<QueueFilters>) =>
    setFilters((f) => ({ ...f, ...p }));

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
  // 選択肢値（言語等）は value は正準値のまま、表示ラベルのみ翻訳する。
  const enumOpts = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: enumLabel(t, x) }));

  return (
    <>
      <div className="page-header">
        <h1>{t('review.title')}</h1>
        <p>{t('review.subtitle')}</p>
      </div>

      {/* 快速タブ（DataStatus 群） */}
      <div className="review-tabs">
        {QUEUE_TABS.map((tb) => (
          <button
            key={tb.key}
            className={`chip${tab === tb.key ? ' on' : ''}`}
            onClick={() => {
              if (!confirmLeave()) return;
              dirtyRef.current = false;
              setTab(tb.key);
            }}
          >
            {t(tb.labelKey)}
          </button>
        ))}
      </div>

      <div className="card filters-bar">
        {sel(t('filters.mode'), filters.entryMode ?? '', translated(ENTRY_MODES),
          (v) => patchFilters({ entryMode: v || undefined }))}
        {sel(t('filters.language'), filters.mainLanguage ?? '',
          enumOpts(languageFilterValues(schema?.enums['主要言語'])),
          (v) => patchFilters({ mainLanguage: v || undefined }))}
        {sel(t('filters.area'), filters.areaCode ?? '', raw(areas),
          (v) => patchFilters({ areaCode: v || undefined }))}
        <label className="filter-field">
          <span>{t('filters.dataset')}</span>
          <select
            value={filters.datasetId != null ? String(filters.datasetId) : ''}
            onChange={(e) =>
              patchFilters({ datasetId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">{t('common.all')}</option>
            {datasets.map((d) => (
              <option key={d.id} value={d.id}>{`#${d.id} ${d.name}`}</option>
            ))}
          </select>
        </label>
        <span className="spacer" />
        <span className="muted total">
          {items != null ? t('review.inQueue', { n: total }) : ''}
          {items != null && total > QUEUE_PAGE_SIZE &&
            ` ${t('review.showingFirst', { n: QUEUE_PAGE_SIZE })}`}
        </span>
        <button className="btn" onClick={() => setFilters({})}>{t('common.clearFilters')}</button>
        <button className="btn" onClick={() => fetchQueue(false)}>{t('common.refresh')}</button>
        <button className="btn" disabled={selectedId == null} onClick={skipNext}>
          {t('review.skipNext')}
        </button>
      </div>

      {error && (
        <div className="error-box">
          <strong>{t('review.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {!error && items != null && items.length === 0 && (
        <div className="placeholder">
          <p>
            {Object.values(filters).some((v) => v !== undefined)
              ? t('review.allReviewed')
              : t('review.emptyQueue')}
          </p>
        </div>
      )}

      {!error && items != null && items.length > 0 && (
        <div className="review-main">
          <ReviewQueue items={items} selectedId={selectedId} onSelect={select} />
          {selectedId != null ? (
            <ReviewWorkspace
              recordId={selectedId}
              schema={schema}
              onDirtyChange={(d) => { dirtyRef.current = d; }}
              onActioned={handleActioned}
            />
          ) : (
            <div className="card review-workspace muted">
              {t('review.selectPrompt')}
            </div>
          )}
        </div>
      )}
    </>
  );
}
