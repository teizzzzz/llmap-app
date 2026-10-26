import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ApiError, getRecords } from '../api/client';
import type { RecordsQuery, RecordsResponse } from '../api/types';
import ImportDatasetDialog from '../components/database/ImportDatasetDialog';
import RecordDetailPanel from '../components/database/RecordDetailPanel';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsMasonry, { ThumbSlider, useThumbSize } from '../components/database/RecordsMasonry';
import RecordsTable from '../components/database/RecordsTable';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters, { hasAnyFilter } from '../hooks/useSharedFilters';
import { languageFilterValues } from '../lib/languageList';

const PAGE_SIZE = 50;

export default function DatabasePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { filters, patch, clear } = useSharedFilters();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [albumTotal, setAlbumTotal] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [importing, setImporting] = useState(false);
  const [view, setView] = useState<'table' | 'album'>(() => {
    try { return localStorage.getItem('llmap.dbView') === 'album' ? 'album' : 'table'; } catch { return 'table'; }
  });
  useEffect(() => {
    try { localStorage.setItem('llmap.dbView', view); } catch { /* 保存できなくても表示は切替わる */ }
  }, [view]);
  const [thumb, setThumb] = useThumbSize();

  const { schema, datasets, areas, collectors, fieldStats,
    refresh: fetchOptions } = useFilterOptions();

  // Map の popup「在数据库中打开」からの遷移: ?record=<id> を選択状態に反映。
  const [searchParams, setSearchParams] = useSearchParams();
  useEffect(() => {
    const rid = searchParams.get('record');
    const v = searchParams.get('view');
    if (v === 'table' || v === 'album') setView(v);
    if (rid) {
      setSelectedId(Number(rid));
      setView('table');
    }
    if (rid || v) setSearchParams({}, { replace: true }); // 一度反映したら URL を掃除
  }, [searchParams, setSearchParams]);

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

  // 筛选変更は必ず 1 ページ目へ戻す。
  const patchFilters = useCallback((p: Partial<RecordsQuery>) => {
    patch(p);
    setPage(1);
  }, [patch]);

  const lastPage = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const total = view === 'table' ? data?.total ?? null : albumTotal;

  return (
    <>
      <div className="page-head">
        <h1>{t('database.title')}<span className="page-count">{total ?? ''}</span></h1>
        <div className="page-actions">
          <div className="seg">
            <button type="button" className={view === 'table' ? 'on' : ''} onClick={() => setView('table')}>
              {t('database.viewTable')}
            </button>
            <button type="button" className={view === 'album' ? 'on' : ''} onClick={() => setView('album')}>
              {t('database.viewAlbum')}
            </button>
          </div>
          <button className="btn" onClick={() => setImporting(true)}>{t('database.import')}</button>
          <button className="btn primary" onClick={() => navigate('/export')}>
            {t('database.exportFiltered')} <span aria-hidden="true">→</span>
          </button>
        </div>
      </div>

      {importing && (
        <ImportDatasetDialog
          onClose={() => setImporting(false)}
          onImported={() => { fetchRecords(); fetchOptions(); }}
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
        total={total}
        onChange={patchFilters}
        onClear={() => { clear(); setPage(1); }}
        trailing={view === 'album' ? <ThumbSlider value={thumb} onChange={setThumb} /> : null}
      />

      {view === 'album' && (
        <RecordsMasonry filters={filters} thumb={thumb} onThumb={setThumb} onTotal={setAlbumTotal} />
      )}

      {view === 'table' && (
        <div className="db-main">
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
                <RecordsTable items={data.items} selectedId={selectedId} onSelect={setSelectedId} />
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

          {selectedId != null && (
            <RecordDetailPanel recordId={selectedId} schema={schema} onSaved={fetchRecords} />
          )}
        </div>
      )}
    </>
  );
}
