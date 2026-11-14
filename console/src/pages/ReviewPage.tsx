import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchParams } from 'react-router-dom';
import { ApiError, getRecords } from '../api/client';
import type { RecordItem, RecordsQuery } from '../api/types';
import ScopeBanner from '../components/ScopeBanner';
import ReviewQueue from '../components/review/ReviewQueue';
import ReviewWorkspace from '../components/review/ReviewWorkspace';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters, { scopeQuery, type ScopeKind } from '../hooks/useSharedFilters';
import { enumLabel } from '../lib/enumLabels';
import { languageFilterValues } from '../lib/languageList';
import { SelectDropdown } from '../components/Dropdown';
import { PENDING_STATUSES, QUEUE_TABS } from '../reviewStatus';
import { confirmLeave } from '../lib/unsavedGuard';

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const QUEUE_PAGE_SIZE = 100;
const QUEUE_OPEN_KEY = 'llmap.reviewQueueOpen';

interface QueueFilters {
  entryMode?: string;
  mainLanguage?: string;
  areaCode?: string;
  datasetId?: number;
}

/** 審核: 左＝队列（畳める）・中＝写真・右＝研究字段と固定の操作欄。
    資料庫の「审核当前筛选」から来たときは、その筛选（＝資料庫の範囲）を
    队列の母集団にし、帯で範囲を明示する。状態の絞り込みは上のタブが担う。 */
export default function ReviewPage() {
  const { t } = useTranslation();
  const [params, setParams] = useSearchParams();
  const shared = useSharedFilters();
  // 資料庫の範囲を使うか（?scope=db で来たとき。帯から「全部」に戻せる）。
  // 資料庫から来たときの範囲: db = 筛选結果（空なら全部の記録）、sel = 手動選択。
  const [scope, setScope] = useState<ScopeKind | null>(() => {
    const s = params.get('scope');
    return s === 'db' || s === 'sel' || (s === 'rec' && params.get('record')) ? s as ScopeKind : null;
  });
  // 记录详情の「进入审核」: その 1 件（?record=）。
  const [recordId] = useState<number | null>(() => (params.get('record') ? Number(params.get('record')) : null));
  const useDbScope = scope != null;
  const scopeFilters = scope ? scopeQuery(scope, shared.filters, shared.selection, recordId) : {};
  useEffect(() => {
    if (params.get('scope')) setParams({}, { replace: true });
  }, [params, setParams]);

  const [tab, setTab] = useState('pending'); // 既定: raw/submitted/ai_drafted(+needs_review)
  const [singleLabel, setSingleLabel] = useState('');
  // 1 件の審核: その記録の状態のタブで開く（審核済みの記録も见直せるように）。
  useEffect(() => {
    if (scope !== 'rec' || recordId == null) return;
    getRecords({ ids: [recordId], page: 1, pageSize: 1 }).then((r) => {
      const it = r.items[0];
      if (!it) return;
      const st = String(it.DataStatus ?? '');
      setTab(PENDING_STATUSES.includes(st) ? 'pending' : QUEUE_TABS.some((x) => x.key === st) ? st : 'pending');
      setSingleLabel(String(it.DisplayID || it.SignID));
    }).catch(() => {});
  }, [scope, recordId]);
  const [filters, setFilters] = useState<QueueFilters>({});
  const [items, setItems] = useState<RecordItem[] | null>(null);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const { schema, datasets, areas } = useFilterOptions();
  const [queueOpen, setQueueOpen] = useState(() => {
    try { return localStorage.getItem(QUEUE_OPEN_KEY) !== '0'; } catch { return true; }
  });
  useEffect(() => {
    try { localStorage.setItem(QUEUE_OPEN_KEY, queueOpen ? '1' : '0'); } catch { /* 表示は切替わる */ }
  }, [queueOpen]);

  // 未保存の保護は共通の確認（保存して続ける／破棄／キャンセル）。
  const leave = () => confirmLeave('page');

  const statuses =
    QUEUE_TABS.find((tb) => tb.key === tab)?.statuses ?? QUEUE_TABS[0].statuses;

  // 队列の母集団: 資料庫の範囲（状態条件は外し、タブの状態で絞る）か、ページ内の筛选。
  const base: RecordsQuery = useDbScope
    ? { ...scopeFilters, dataStatus: undefined }
    : filters;

  // 古い応答で新しい結果を上書きしない（タブ・範囲を続けて変えたとき）。
  const fetchSeq = useRef(0);
  const fetchQueue = useCallback(
    (selectFirst: boolean) => {
      // 1 件の審核は、その記録の状態のタブが決まってから読む。
      if (scope === 'rec' && !singleLabel) return;
      const seq = ++fetchSeq.current;
      setError(null);
      getRecords({
        ...base,
        dataStatus: statuses.join(','),
        page: 1,
        pageSize: QUEUE_PAGE_SIZE,
      })
        .then((res) => {
          if (seq !== fetchSeq.current) return;
          setItems(res.items);
          setTotal(res.total);
          if (selectFirst) {
            setSelectedId(res.items[0]?.id ?? null);
          }
        })
        .catch((e: unknown) => {
          if (seq !== fetchSeq.current) return;
          setItems(null);
          setError(e instanceof ApiError ? e.message : String(e));
        });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [filters, tab, scope, shared.filters, shared.selection, singleLabel],
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

  const select = async (id: number) => {
    if (id === selectedId || !(await leave())) return;
    setSelectedId(id);
  };

  const patchFilters = async (p: Partial<QueueFilters>) => {
    if (!(await leave())) return;
    setFilters((f) => ({ ...f, ...p }));
  };

  // 前・次（J / K と操作欄のボタンで共通）。
  const list = items ?? [];
  const index = list.findIndex((r) => r.id === selectedId);
  const move = (d: 1 | -1) => {
    const next = list[index + d];
    if (next) void select(next.id);
  };
  const moveRef = useRef(move);
  moveRef.current = move;
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      const k = e.key.toLowerCase();
      if (k === 'j') { e.preventDefault(); moveRef.current(1); }
      if (k === 'k') { e.preventDefault(); moveRef.current(-1); }
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
  const position = index + 1;
  const tabLabel = t(QUEUE_TABS.find((tb) => tb.key === tab)?.labelKey ?? 'review.tabs.pending');

  return (
    <div className="review-page">
      <div className="page-head compact">
        <h1>{t('review.title')}</h1>
        {items != null && total > 0 && (
          <div className="rv-progress">
            <span className="mono">{position || '—'} / {total}</span>
            <span className="rv-progress-bar">
              <i style={{ width: `${total ? (position / total) * 100 : 0}%` }} />
            </span>
          </div>
        )}
      </div>

      {useDbScope && (
        <ScopeBanner
          filters={{ ...scopeFilters, dataStatus: undefined }}
          datasets={datasets}
          count={total}
          countLabel={t('review.scopeCount', { tab: tabLabel, n: total })}
          single={scope === 'rec' ? singleLabel || String(recordId) : undefined}
          onReset={async () => {
            if (!(await leave())) return;
            setScope(null);
          }}
          resetLabel={t('review.scopeReset')}
        />
      )}

      <div className="rv-toolbar">
        <button type="button" className="btn ghost icon" onClick={() => setQueueOpen((v) => !v)}
          title={t(queueOpen ? 'review.hideQueue' : 'review.showQueue')}
          aria-label={t(queueOpen ? 'review.hideQueue' : 'review.showQueue')} aria-pressed={queueOpen}>
          {queueOpen ? '⟨' : '☰'}
        </button>
        <div className="tabs" role="tablist">
          {QUEUE_TABS.map((tb) => (
            <button
              key={tb.key}
              type="button" role="tab" aria-selected={tab === tb.key}
              className={`tab${tab === tb.key ? ' on' : ''}`}
              onClick={async () => {
                if (!(await leave())) return;
                setTab(tb.key);
              }}
            >
              {t(tb.labelKey)}
            </button>
          ))}
        </div>
        <span className="spacer" />
        {/* 資料庫の範囲を使っている間は、範囲は帯で示しページ内の筛选は出さない（二重にしない）。 */}
        {!useDbScope && (
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
        )}
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
            {useDbScope || Object.values(filters).some((v) => v !== undefined)
              ? t('review.allReviewed')
              : t('review.emptyQueue')}
          </p>
        </div>
      )}

      {!error && items != null && items.length > 0 && (
        <div className={`rv-main${queueOpen ? '' : ' queue-closed'}`}>
          {queueOpen && <ReviewQueue items={items} selectedId={selectedId} onSelect={(id) => void select(id)} />}
          {selectedId != null ? (
            <ReviewWorkspace
              recordId={selectedId}
              schema={schema}
              onDirtyChange={() => {}}
              onActioned={handleActioned}
              nav={{
                position,
                total,
                canPrev: index > 0,
                canNext: index >= 0 && index < list.length - 1,
                onPrev: () => move(-1),
                onNext: () => move(1),
              }}
            />
          ) : (
            <div className="rv-viewer muted">{t('review.selectPrompt')}</div>
          )}
        </div>
      )}
    </div>
  );
}
