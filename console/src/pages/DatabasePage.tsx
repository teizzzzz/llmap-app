import { useCallback, useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchParams } from 'react-router-dom';
import { ApiError, getRecords } from '../api/client';
import type { Dataset, RecordsQuery, RecordsResponse } from '../api/types';
import {
  DatasetAlbumGrid, DatasetPhotoGrid,
} from '../components/database/DatasetAlbums';
import ImportDatasetDialog from '../components/database/ImportDatasetDialog';
import RecordDetailPanel from '../components/database/RecordDetailPanel';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsTable from '../components/database/RecordsTable';
import useFilterOptions from '../hooks/useFilterOptions';
import { languageFilterValues } from '../lib/languageList';

const PAGE_SIZES = [25, 50, 100];

export default function DatabasePage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  const [importing, setImporting] = useState(false);
  // 表示モード: 表格 / データセット相册（Step 17）。
  const [view, setView] = useState<'table' | 'albums'>('table');
  const [openAlbum, setOpenAlbum] = useState<Dataset | null>(null);

  // 筛选肢の元データ（Map ページと共用の hook）。
  const { schema, datasets, areas, collectors, fieldStats,
    refresh: fetchOptions } = useFilterOptions();

  // Map の popup「Open in Database」からの遷移: ?record=<id> を選択状態に反映。
  const [searchParams, setSearchParams] = useSearchParams();
  useEffect(() => {
    const rid = searchParams.get('record');
    if (rid) {
      setSelectedId(Number(rid));
      setSearchParams({}, { replace: true }); // 一度反映したら URL を掃除
    }
  }, [searchParams, setSearchParams]);

  const fetchRecords = useCallback(() => {
    setLoading(true);
    setError(null);
    getRecords({ ...filters, page, pageSize })
      .then(setData)
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [filters, page, pageSize]);

  useEffect(fetchRecords, [fetchRecords]);

  // 筛选変更は必ず 1 ページ目へ戻す。
  const patchFilters = useCallback((patch: Partial<RecordsQuery>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(1);
  }, []);

  const hasFilters = useMemo(
    () => Object.values(filters).some((v) => v !== undefined && v !== ''),
    [filters],
  );

  const total = data?.total ?? null;
  const from = data && data.total > 0 ? (data.page - 1) * data.pageSize + 1 : 0;
  const to = data ? Math.min(data.page * data.pageSize, data.total) : 0;
  const lastPage = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <>
      <div className="page-header page-header-row">
        <div>
          <h1>{t('database.title')}</h1>
          <p>{t('database.subtitle')}</p>
        </div>
        <button className="btn primary" onClick={() => setImporting(true)}>
          ⇪ {t('database.import')}
        </button>
      </div>

      {/* 視図切替（表格 / 相册） */}
      <div className="review-tabs">
        <button
          className={`chip${view === 'table' ? ' on' : ''}`}
          onClick={() => { setView('table'); setOpenAlbum(null); }}
        >
          {t('database.viewTable')}
        </button>
        <button
          className={`chip${view === 'albums' ? ' on' : ''}`}
          onClick={() => setView('albums')}
        >
          {t('database.viewAlbums')}
        </button>
      </div>

      {importing && (
        <ImportDatasetDialog
          onClose={() => setImporting(false)}
          onImported={() => {
            fetchRecords(); // 表格
            fetchOptions(); // datasets / 地区・採集者の筛选肢（Dashboard は次回表示時に反映）
          }}
        />
      )}

      {view === 'albums' && (
        openAlbum ? (
          <DatasetPhotoGrid
            dataset={openAlbum}
            onBack={() => setOpenAlbum(null)}
            onOpenInTable={() => {
              patchFilters({ datasetIds: [openAlbum.id] });
              setOpenAlbum(null);
              setView('table');
            }}
          />
        ) : (
          <DatasetAlbumGrid datasets={datasets} onOpen={setOpenAlbum} />
        )
      )}

      {view === 'table' && (
      <>
      <RecordsFilters
        value={filters}
        options={{
          languages: languageFilterValues(schema?.enums['主要言語']),
          areas,
          collectors,
          datasets,
        }}
        schemaEnums={schema?.enums}
        fieldPresence={fieldStats}
        total={total}
        onChange={patchFilters}
        onClear={() => {
          setFilters({});
          setPage(1);
        }}
        onRefresh={fetchRecords}
      />

      <div className="db-main">
        <div className="table-wrap">
          {error && (
            <div className="error-box">
              <strong>{t('database.loadError')}</strong>
              <div className="hint">{error}</div>
            </div>
          )}
          {!error && loading && <div className="card muted">{t('database.loading')}</div>}
          {!error && !loading && data && data.items.length === 0 && (
            <div className="placeholder">
              {hasFilters ? (
                <p>{t('database.noMatch')}</p>
              ) : (
                <p>{t('database.empty', { button: t('database.import') })}</p>
              )}
            </div>
          )}
          {!error && data && data.items.length > 0 && (
            <>
              <div className="card table-card">
                <RecordsTable
                  items={data.items}
                  selectedId={selectedId}
                  onSelect={setSelectedId}
                />
              </div>
              <div className="pagination">
                <button className="btn" disabled={page <= 1} onClick={() => setPage(page - 1)}>
                  {t('database.prev')}
                </button>
                <span className="muted">
                  {t('database.range', { from, to, total: data.total })}
                </span>
                <button
                  className="btn"
                  disabled={page >= lastPage}
                  onClick={() => setPage(page + 1)}
                >
                  {t('database.next')}
                </button>
                <span className="spacer" />
                <label className="filter-field">
                  <span>{t('database.pageSize')}</span>
                  <select
                    value={pageSize}
                    onChange={(e) => {
                      setPageSize(Number(e.target.value));
                      setPage(1);
                    }}
                  >
                    {PAGE_SIZES.map((n) => (
                      <option key={n} value={n}>{n}</option>
                    ))}
                  </select>
                </label>
              </div>
            </>
          )}
        </div>

        {selectedId != null && (
          <RecordDetailPanel
            recordId={selectedId}
            schema={schema}
            onSaved={fetchRecords}
          />
        )}
      </div>
      </>
      )}
    </>
  );
}
