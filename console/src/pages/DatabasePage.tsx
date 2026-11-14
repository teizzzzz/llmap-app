import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ApiError, getRecords } from '../api/client';
import type { RecordsQuery, RecordsResponse } from '../api/types';
import MenuButton from '../components/MenuButton';
import ImportDatasetDialog from '../components/database/ImportDatasetDialog';
import RecordDetailPanel from '../components/database/RecordDetailPanel';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsMasonry, { ThumbSlider, useThumbSize } from '../components/database/RecordsMasonry';
import RecordsTable from '../components/database/RecordsTable';
import useAiEnabled from '../hooks/useAiEnabled';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters, { hasAnyFilter } from '../hooks/useSharedFilters';
import { languageFilterValues } from '../lib/languageList';

const PAGE_SIZE = 50;
const VIEW_KEY = 'llmap.dbView';

/** 資料庫（既定の入口）。写真（相册）と表格を切り替え、記録の详情は
    右の抽屉で開く（一覧の筛选・スクロール位置・縮略図サイズはそのまま）。
    ここでの筛选は「資料庫の現在の範囲」として審核・AI・導出へ引き継ぐ。 */
export default function DatabasePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const {
    filters, patch, replace, clear,
    selection, toggleSelect, setSelection, clearSelection,
  } = useSharedFilters();
  const [aiOn] = useAiEnabled();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [albumTotal, setAlbumTotal] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [importing, setImporting] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);
  // 視図: 好みが未保存なら写真（相册）。以後は前回の選択を覚える。
  const [view, setView] = useState<'table' | 'album'>(() => {
    try { return localStorage.getItem(VIEW_KEY) === 'table' ? 'table' : 'album'; } catch { return 'album'; }
  });
  useEffect(() => {
    try { localStorage.setItem(VIEW_KEY, view); } catch { /* 保存できなくても表示は切替わる */ }
  }, [view]);
  const [thumb, setThumb] = useThumbSize();

  const { schema, datasets, areas, collectors, fieldStats,
    refresh: fetchOptions } = useFilterOptions();

  // 详情の未保存変更（閉じる・別の記録へ切替える前に確認する）。
  const dirtyRef = useRef(false);
  const onDirtyChange = useCallback((d: boolean) => { dirtyRef.current = d; }, []);
  const openRecord = (id: number | null) => {
    if (id === selectedId) return;
    if (dirtyRef.current && !window.confirm(t('review.confirmDiscard'))) return;
    dirtyRef.current = false;
    setSelectedId(id);
  };

  // Map の popup「在数据库中打开」等からの遷移: ?record=<id> を详情で開く。
  const [searchParams, setSearchParams] = useSearchParams();
  useEffect(() => {
    const rid = searchParams.get('record');
    const v = searchParams.get('view');
    if (v === 'table' || v === 'album') setView(v);
    if (rid) setSelectedId(Number(rid));
    if (rid || v) setSearchParams({}, { replace: true }); // 一度反映したら URL を掃除
  }, [searchParams, setSearchParams]);

  // 详情の抽屉: Esc で閉じる（写真ビューア表示中はビューア側に譲る）。
  useEffect(() => {
    if (selectedId == null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape' || document.querySelector('.lightbox-overlay, .modal-overlay')) return;
      openRecord(null);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const fetchRecords = useCallback(() => {
    if (view !== 'table') return;
    setLoading(true);
    setError(null);
    getRecords({ ...filters, page, pageSize: PAGE_SIZE })
      .then(setData)
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [filters, page, view]);
  useEffect(fetchRecords, [fetchRecords]);

  // 範囲全体の件数（写真の有無を問わない）と、そのうち写真の無い件数。
  // 相册は写真のある記録だけを並べるので、差を明示して表格で見られるようにする。
  const [scopeTotal, setScopeTotal] = useState<number | null>(null);
  const [noPhoto, setNoPhoto] = useState<number | null>(null);
  useEffect(() => {
    let stale = false;
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => { if (!stale) setScopeTotal(r.total); })
      .catch(() => { if (!stale) setScopeTotal(null); });
    if (filters.hasPhoto === undefined) {
      getRecords({ ...filters, hasPhoto: false, page: 1, pageSize: 1 })
        .then((r) => { if (!stale) setNoPhoto(r.total); })
        .catch(() => { if (!stale) setNoPhoto(null); });
    } else {
      setNoPhoto(null);
    }
    return () => { stale = true; };
  }, [filters, reloadKey]);

  // 筛选変更は必ず 1 ページ目へ戻す。
  const patchFilters = useCallback((p: Partial<RecordsQuery>) => {
    patch(p);
    setPage(1);
  }, [patch]);

  const afterSave = () => {
    fetchRecords();
    setReloadKey((k) => k + 1);
  };

  /** 導入直後: 今回の導入分（データセット）だけに絞って写真で見る。 */
  const viewImported = (datasetId: number) => {
    replace({ datasetIds: [datasetId] });
    setPage(1);
    setView('album');
    setImporting(false);
  };

  const lastPage = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const shown = view === 'table' ? data?.total ?? null : albumTotal;
  const n = scopeTotal ?? 0;

  return (
    <div className="db-page">
      <div className="page-head compact">
        <h1>{t('database.title')}</h1>
        <div className="page-actions">
          <div className="seg" role="tablist" aria-label={t('database.view')}>
            <button type="button" role="tab" aria-selected={view === 'album'}
              className={view === 'album' ? 'on' : ''} onClick={() => setView('album')}>
              {t('database.viewAlbum')}
            </button>
            <button type="button" role="tab" aria-selected={view === 'table'}
              className={view === 'table' ? 'on' : ''} onClick={() => setView('table')}>
              {t('database.viewTable')}
            </button>
          </div>
          <button className="btn" onClick={() => setImporting(true)}>{t('database.import')}</button>
          {/* 現在の範囲（筛选結果）をそのまま次の作業へ。対象と件数をボタンに明記する。 */}
          <MenuButton className="btn primary" label={t('database.scopeMenu', { n })}>
            {(close) => (
              <>
                <button type="button" role="menuitem" className="menu-item" disabled={!n}
                  onClick={() => { close(); navigate('/review?scope=db'); }}>
                  {t('database.scopeReview', { n })}
                </button>
                {aiOn && (
                  <button type="button" role="menuitem" className="menu-item" disabled={!n}
                    onClick={() => { close(); navigate('/ai?scope=db'); }}>
                    {t('database.scopeAi', { n })}
                  </button>
                )}
                <button type="button" role="menuitem" className="menu-item" disabled={!n}
                  onClick={() => { close(); navigate('/export?scope=db'); }}>
                  {t('database.scopeExport', { n })}
                </button>
              </>
            )}
          </MenuButton>
        </div>
      </div>

      {importing && (
        <ImportDatasetDialog
          onClose={() => setImporting(false)}
          onImported={() => { fetchRecords(); fetchOptions(); setReloadKey((k) => k + 1); }}
          onViewImported={viewImported}
          aiOn={aiOn}
        />
      )}

      <RecordsFilters
        value={filters}
        options={{
          languages: languageFilterValues(schema?.enums['主要言語']),
          areas, collectors, datasets,
        }}
        schemaEnums={schema?.enums}
        fieldPresence={fieldStats}
        total={view === 'table' ? shown : scopeTotal}
        onChange={patchFilters}
        onClear={() => { clear(); setPage(1); }}
        trailing={view === 'album' ? <ThumbSlider value={thumb} onChange={setThumb} /> : null}
      />

      {/* 相册は写真のある記録だけ。写真の無い記録の件数と見る方法を明示する。 */}
      {view === 'album' && (noPhoto ?? 0) > 0 && (
        <div className="note-line">
          {t('database.albumNoPhotoNote', { shown: albumTotal ?? '—', missing: noPhoto })}
          <button type="button" className="link-btn"
            onClick={() => { patchFilters({ hasPhoto: false }); setView('table'); }}>
            {t('database.showNoPhoto')}
          </button>
        </div>
      )}

      {view === 'album' && (
        <RecordsMasonry filters={filters} thumb={thumb} onThumb={setThumb} onTotal={setAlbumTotal}
          onOpen={(r) => openRecord(r.id)} selectedId={selectedId} reloadKey={reloadKey}
          checked={selection} onToggleCheck={toggleSelect} />
      )}

      {view === 'table' && (
        <div className="table-wrap">
          {error && (
            <div className="error-box">
              <strong>{t('database.loadError')}</strong>
              <div className="hint">{error}</div>
            </div>
          )}
          {!error && loading && !data && <div className="muted">{t('database.loading')}</div>}
          {!error && !loading && data && data.items.length === 0 && (
            <div className="placeholder">
              <p>{hasAnyFilter(filters)
                ? t('database.noMatch')
                : t('database.empty', { button: t('database.import') })}</p>
            </div>
          )}
          {!error && data && data.items.length > 0 && (
            <>
              <RecordsTable items={data.items} selectedId={selectedId} onSelect={openRecord}
                checked={selection} onToggleCheck={toggleSelect}
                onToggleAll={(ids, on) => setSelection(on
                  ? [...selection, ...ids.filter((id) => !selection.includes(id))]
                  : selection.filter((id) => !ids.includes(id)))} />
              {lastPage > 1 && (
                <div className="pagination">
                  <button className="btn ghost" disabled={page <= 1} onClick={() => setPage(page - 1)}>←</button>
                  <span className="mono">{page} / {lastPage}</span>
                  <button className="btn ghost" disabled={page >= lastPage} onClick={() => setPage(page + 1)}>→</button>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* 手動選択の操作帯: 筛选結果（上のメニュー）とは別に、選んだ記録だけに効く。 */}
      {selection.length > 0 && (
        <div className="select-bar" role="region" aria-label={t('database.selectionBar')}>
          <span className="select-n">{t('database.selectedCount', { n: selection.length })}</span>
          <button type="button" className="btn ghost" onClick={clearSelection}>
            {t('database.clearSelection')}
          </button>
          <span className="spacer" />
          <button type="button" className="btn" onClick={() => navigate('/review?scope=sel')}>
            {t('database.selReview', { n: selection.length })}
          </button>
          {aiOn && (
            <button type="button" className="btn" onClick={() => navigate('/ai?scope=sel')}>
              {t('database.selAi', { n: selection.length })}
            </button>
          )}
          <button type="button" className="btn primary" onClick={() => navigate('/export?scope=sel')}>
            {t('database.selExport', { n: selection.length })}
          </button>
        </div>
      )}

      {/* 详情は一覧の上に重ねる抽屉（一覧の幅・スクロールを変えない）。 */}
      {selectedId != null && (
        <div className="drawer" role="dialog" aria-label={t('record.detail')}>
          <RecordDetailPanel recordId={selectedId} schema={schema} onSaved={afterSave}
            onClose={() => openRecord(null)} onDirtyChange={onDirtyChange} />
        </div>
      )}
    </div>
  );
}
