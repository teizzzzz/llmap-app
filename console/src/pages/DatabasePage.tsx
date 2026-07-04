import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ApiError,
  getDatasets,
  getRecords,
  getSchema,
  getStatsSummary,
} from '../api/client';
import type {
  Dataset,
  RecordsQuery,
  RecordsResponse,
  SchemaInfo,
} from '../api/types';
import RecordDetailPanel from '../components/database/RecordDetailPanel';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsTable from '../components/database/RecordsTable';

const PAGE_SIZES = [25, 50, 100];

export default function DatabasePage() {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  // 筛选肢の元データ（schema の言語 enum、実在の地区/採集者、dataset 一覧）。
  const [schema, setSchema] = useState<SchemaInfo | null>(null);
  const [datasets, setDatasets] = useState<Dataset[]>([]);
  const [areas, setAreas] = useState<string[]>([]);
  const [collectors, setCollectors] = useState<string[]>([]);

  useEffect(() => {
    getSchema().then(setSchema).catch(() => {});
    getDatasets().then(setDatasets).catch(() => {});
    getStatsSummary()
      .then((s) => {
        setAreas(Object.keys(s.areaCounts).filter((k) => k !== 'unknown'));
        setCollectors(Object.keys(s.collectorCounts).filter((k) => k !== 'unknown'));
      })
      .catch(() => {});
  }, []);

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
      <div className="page-header">
        <h1>Database</h1>
        <p>
          Manage imported linguistic landscape records.{' '}
          <span className="muted">
            To import data, use backend <code>POST /datasets/import</code> for now.
          </span>
        </p>
      </div>

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
                  No records yet. Import a Dataset Package via backend{' '}
                  <code>POST /datasets/import</code>.
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
