import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ApiError, getRecords } from '../api/client';
import type { RecordsQuery, RecordsResponse } from '../api/types';
import ImportDatasetDialog from '../components/database/ImportDatasetDialog';
import RecordDetailPanel from '../components/database/RecordDetailPanel';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsTable from '../components/database/RecordsTable';
import useFilterOptions from '../hooks/useFilterOptions';

const PAGE_SIZES = [25, 50, 100];

export default function DatabasePage() {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  const [importing, setImporting] = useState(false);

  // 筛选肢の元データ（Map ページと共用の hook）。
  const { schema, datasets, areas, collectors, refresh: fetchOptions } =
    useFilterOptions();

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
          <h1>Database</h1>
          <p>Manage imported linguistic landscape records.</p>
        </div>
        <button className="btn primary" onClick={() => setImporting(true)}>
          ⇪ Import Dataset Package
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

      <RecordsFilters
        value={filters}
        options={{
          languages: schema?.enums['主要言語'] ?? [],
          areas,
          collectors,
          datasets,
        }}
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
              <strong>Could not load records.</strong>
              <div className="hint">{error}</div>
            </div>
          )}
          {!error && loading && <div className="card muted">Loading records…</div>}
          {!error && !loading && data && data.items.length === 0 && (
            <div className="placeholder">
              {hasFilters ? (
                <p>No records match the current filters.</p>
              ) : (
                <p>
                  No records yet. Click “Import Dataset Package” above to upload a
                  package exported from LLMap Mobile.
                </p>
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
                  ← Prev
                </button>
                <span className="muted">
                  {from}–{to} of {data.total}
                </span>
                <button
                  className="btn"
                  disabled={page >= lastPage}
                  onClick={() => setPage(page + 1)}
                >
                  Next →
                </button>
                <span className="spacer" />
                <label className="filter-field">
                  <span>Page size</span>
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
  );
}
