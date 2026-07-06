import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, exportRecordsCsv, getRecords } from '../api/client';
import type { RecordsQuery } from '../api/types';
import RecordsFilters from '../components/database/RecordsFilters';
import useFilterOptions from '../hooks/useFilterOptions';

/** 快速筛选プリセット。patch の状態値は内部値のまま（表示のみ翻訳）。 */
const QUICK_FILTERS: { labelKey: string; patch: RecordsQuery }[] = [
  { labelKey: 'export.quickAll', patch: {} },
  { labelKey: 'export.quickReviewed', patch: { dataStatus: 'reviewed' } },
  { labelKey: 'export.quickVerified', patch: { dataStatus: 'verified' } },
  { labelKey: 'export.quickGps', patch: { hasGps: true } },
  { labelKey: 'export.quickPhotos', patch: { hasPhoto: true } },
];

/** 导出フォーマットカード（第一版は CSV のみ有効）。 */
const FORMATS = [
  { key: 'csv', titleKey: 'export.formatCsvTitle', descKey: 'export.formatCsvDesc', enabled: true },
  { key: 'dataset', titleKey: 'export.formatDatasetTitle', descKey: 'export.formatDatasetDesc', enabled: false },
  { key: 'geojson', titleKey: 'export.formatGeojsonTitle', descKey: 'export.formatGeojsonDesc', enabled: false },
  { key: 'photos', titleKey: 'export.formatPhotosTitle', descKey: 'export.formatPhotosDesc', enabled: false },
];

// 导出ファイル名（データ側の規約なので言語によらず固定）。
const stamp = () => {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}` +
    `_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
};

export default function ExportPage() {
  const { t } = useTranslation();
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
        <h1>{t('export.title')}</h1>
        <p>{t('export.subtitle')}</p>
      </div>

      <div className="card" style={{ marginBottom: 14 }}>
        <p style={{ margin: 0 }} className="muted">{t('export.csvNote')}</p>
      </div>

      {/* 快速筛选 */}
      <div className="review-tabs">
        {QUICK_FILTERS.map((qf) => (
          <button
            key={qf.labelKey}
            className="chip"
            onClick={() => {
              setDone(null);
              setFilters(qf.patch);
            }}
          >
            {t(qf.labelKey)}
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
          <strong>{t('export.countError')}</strong>
          <div className="hint">{countError}</div>
        </div>
      )}

      {/* 导出摘要 */}
      <div className="card export-summary">
        <div>
          <div className="label muted">{t('export.matching')}</div>
          <div className="value">{total != null ? total : '—'}</div>
        </div>
        <button
          className="btn primary"
          disabled={exporting || total === 0 || total == null}
          onClick={doExport}
        >
          {exporting ? t('export.exporting') : t('export.exportCsv')}
        </button>
      </div>

      {done && (
        <div className="ok-box">
          {t('export.exportedAs')} <span className="mono">{done}</span>{' '}
          {t('export.exportedCount', { n: total })}
        </div>
      )}
      {exportError && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <strong>{t('export.failed')}</strong>
          <div className="hint">{exportError}</div>
        </div>
      )}

      {/* フォーマット一覧（CSV 以外は予約・無効） */}
      <h3 className="detail-section" style={{ marginTop: 22 }}>{t('export.formats')}</h3>
      <div className="format-grid">
        {FORMATS.map((f) => (
          <div key={f.key} className={`card format-card${f.enabled ? '' : ' disabled'}`}>
            <div className="format-head">
              <strong>{t(f.titleKey)}</strong>
              {f.enabled ? (
                <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
                  {t('export.available')}
                </span>
              ) : (
                <span className="badge" style={{ color: '#6f6a61', borderColor: '#6f6a6155', background: '#6f6a6114' }}>
                  {t('common.comingSoon')}
                </span>
              )}
            </div>
            <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>{t(f.descKey)}</p>
          </div>
        ))}
      </div>
    </>
  );
}
