import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getRecords } from '../api/client';
import type { RecordItem } from '../api/types';
import ReviewQueue from '../components/review/ReviewQueue';
import ReviewWorkspace from '../components/review/ReviewWorkspace';
import useFilterOptions from '../hooks/useFilterOptions';
import { enumLabel } from '../lib/enumLabels';
import { languageFilterValues } from '../lib/languageList';
import { SelectDropdown } from '../components/Dropdown';
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

  const select = (id: number) => {
    if (id === selectedId || !confirmLeave()) return;
    dirtyRef.current = false;
    setSelectedId(id);
  };

  const patchFilters = (p: Partial<QueueFilters>) =>
    setFilters((f) => ({ ...f, ...p }));

  // J / K で队列の次・前へ（入力中は無効）。
  const moveRef = useRef<((d: 1 | -1) => void) | null>(null);
  moveRef.current = (d) => {
    const list = items ?? [];
    const i = list.findIndex((r) => r.id === selectedId);
    const next = list[i + d];
    if (next) select(next.id);
  };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      const k = e.key.toLowerCase();
      if (k === 'j') { e.preventDefault(); moveRef.current?.(1); }
      if (k === 'k') { e.preventDefault(); moveRef.current?.(-1); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const raw = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  const translated = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));
  // 選択肢値（言語等）は value は正準値のまま、表示ラベルのみ翻訳する。
  const enumOpts = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: enumLabel(t, x) }));
  const position = (items ?? []).findIndex((r) => r.id === selectedId) + 1;

  return (
    <div className="review-page">
      <div className="page-head">
        <h1>{t('review.title')}<span className="page-count">{items != null ? total : ''}</span></h1>
        {items != null && total > 0 && (
          <div className="rv-progress">
            <span className="mono">{position || '—'} / {total}</span>
            <span className="rv-progress-bar">
              <i style={{ width: `${total ? (position / total) * 100 : 0}%` }} />
            </span>
          </div>
        )}
      </div>

      <div className="rv-toolbar">
        <div className="chip-row">
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
        <span className="spacer" />
        <div className="dd-row">
          <SelectDropdown label={t('filters.mode')} value={filters.entryMode ?? ''}
            options={translated(ENTRY_MODES)}
            onChange={(v) => patchFilters({ entryMode: v || undefined })} />
          <SelectDropdown label={t('filters.language')} value={filters.mainLanguage ?? ''}
            options={enumOpts(languageFilterValues(schema?.enums['主要言語']))}
            onChange={(v) => patchFilters({ mainLanguage: v || undefined })} />
          <SelectDropdown label={t('filters.area')} value={filters.areaCode ?? ''}
            options={raw(areas)}
            onChange={(v) => patchFilters({ areaCode: v || undefined })} />
          <SelectDropdown label={t('filters.dataset')}
            value={filters.datasetId != null ? String(filters.datasetId) : ''}
            options={datasets.map((d) => ({ value: String(d.id), label: d.name }))}
            onChange={(v) => patchFilters({ datasetId: v ? Number(v) : undefined })} />
        </div>
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
        <div className="rv-main">
          <ReviewQueue items={items} selectedId={selectedId} onSelect={select} />
          {selectedId != null ? (
            <ReviewWorkspace
              recordId={selectedId}
              schema={schema}
              onDirtyChange={(d) => { dirtyRef.current = d; }}
              onActioned={handleActioned}
            />
          ) : (
            <div className="rv-viewer muted">{t('review.selectPrompt')}</div>
          )}
        </div>
      )}
    </div>
  );
}
