import { useCallback, useEffect, useState } from 'react';
import { ApiError, exportRecordsCsv, getRecords } from '../api/client';
import type { RecordsQuery } from '../api/types';
import RecordsFilters from '../components/database/RecordsFilters';
import useFilterOptions from '../hooks/useFilterOptions';

/** 快速筛选プリセット。 */
const QUICK_FILTERS: { label: string; patch: RecordsQuery }[] = [
  { label: 'All records', patch: {} },
  { label: 'Reviewed only', patch: { dataStatus: 'reviewed' } },
  { label: 'Verified only', patch: { dataStatus: 'verified' } },
  { label: 'Records with GPS', patch: { hasGps: true } },
  { label: 'Records with photos', patch: { hasPhoto: true } },
];

/** 导出フォーマットカード（第一版は CSV のみ有効）。 */
const FORMATS = [
  {
    key: 'csv',
    title: 'CSV',
    desc: 'All 36 schema columns, UTF-8 with BOM (Excel compatible). Photos are not included.',
    enabled: true,
  },
  {
    key: 'dataset',
    title: 'Dataset Package',
    desc: 'Full re-export as llmap_dataset zip with photos, manifest and schema.',
    enabled: false,
  },
  {
    key: 'geojson',
    title: 'GeoJSON',
    desc: 'Records with GPS as a FeatureCollection for GIS tools.',
    enabled: false,
  },
  {
    key: 'photos',
    title: 'Photos ZIP',
    desc: 'Crop and source photos of the selected records.',
    enabled: false,
  },
];

const stamp = () => {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}` +
    `_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
};

export default function ExportPage() {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [total, setTotal] = useState<number | null>(null);
  const [countError, setCountError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [done, setDone] = useState<string | null>(null); // 保存したファイル名
  const [exportError, setExportError] = useState<string | null>(null);
  const options = useFilterOptions();

  // 筛选後の件数（导出摘要）。pageSize=1 で total だけ取得する。
  const fetchTotal = useCallback(() => {
    setCountError(null);
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => setTotal(r.total))
      .catch((e: unknown) => {
        setTotal(null);
        setCountError(e instanceof ApiError ? e.message : String(e));
      });
  }, [filters]);
  useEffect(fetchTotal, [fetchTotal]);

  const patchFilters = useCallback((patch: Partial<RecordsQuery>) => {
    setDone(null);
    setFilters((f) => ({ ...f, ...patch }));
  }, []);

  const doExport = async () => {
    setExporting(true);
    setExportError(null);
    setDone(null);
    try {
      const blob = await exportRecordsCsv(filters);
      const name = `llmap_export_${stamp()}.csv`;
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = name;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      setDone(name);
    } catch (e: unknown) {
      setExportError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setExporting(false);
    }
  };

  return (
    <>
      <div className="page-header">
        <h1>Export</h1>
        <p>Export filtered database records for analysis and archiving.</p>
      </div>

      <div className="card" style={{ marginBottom: 14 }}>
        <p style={{ margin: 0 }} className="muted">
          CSV export uses the current database records and selected filters.
          System fields such as CaptureID, SignID, EntryMode, DataStatus,
          SchemaVersion, and AppVersion are included. Photos are <b>not</b> included
          in CSV export — use Dataset Package export in a future version when
          images are required.
        </p>
      </div>

      {/* 快速筛选 */}
      <div className="review-tabs">
        {QUICK_FILTERS.map((qf) => (
          <button
            key={qf.label}
            className="chip"
            onClick={() => {
              setDone(null);
              setFilters(qf.patch);
            }}
          >
            {qf.label}
          </button>
        ))}
      </div>

      <RecordsFilters
        value={filters}
        options={{
          languages: options.schema?.enums['主要言語'] ?? [],
          areas: options.areas,
          collectors: options.collectors,
          datasets: options.datasets,
        }}
        total={total}
        onChange={patchFilters}
        onClear={() => {
          setDone(null);
          setFilters({});
        }}
        onRefresh={fetchTotal}
      />

      {countError && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <strong>Could not load record count.</strong>
          <div className="hint">{countError}</div>
        </div>
      )}

      {/* 导出摘要 */}
      <div className="card export-summary">
        <div>
          <div className="label muted">Records matching current filters</div>
          <div className="value">{total != null ? total : '—'}</div>
        </div>
        <button
          className="btn primary"
          disabled={exporting || total === 0 || total == null}
          onClick={doExport}
        >
          {exporting ? 'Exporting…' : 'Export CSV'}
        </button>
      </div>

      {done && (
        <div className="ok-box">
          ✓ CSV exported as <span className="mono">{done}</span> ({total} records).
        </div>
      )}
      {exportError && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <strong>Export failed.</strong>
          <div className="hint">{exportError}</div>
        </div>
      )}

      {/* フォーマット一覧（CSV 以外は予約・無効） */}
      <h3 className="detail-section" style={{ marginTop: 22 }}>Formats</h3>
      <div className="format-grid">
        {FORMATS.map((f) => (
          <div key={f.key} className={`card format-card${f.enabled ? '' : ' disabled'}`}>
            <div className="format-head">
              <strong>{f.title}</strong>
              {f.enabled ? (
                <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
                  available
                </span>
              ) : (
                <span className="badge" style={{ color: '#6f6a61', borderColor: '#6f6a6155', background: '#6f6a6114' }}>
                  Coming soon
                </span>
              )}
            </div>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>{f.desc}</p>
          </div>
        ))}
      </div>
    </>
  );
}
