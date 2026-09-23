import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  ApiError, cancelExportJob, exportGeoJson, exportJobDownloadUrl,
  exportRecordsCsv, getExportJob, getRecords, startPackageExport,
  startPhotosExport,
} from '../api/client';
import type { ExportJobStatus, RecordsQuery } from '../api/types';
import RecordsFilters from '../components/database/RecordsFilters';
import useFilterOptions from '../hooks/useFilterOptions';
import { languageFilterValues } from '../lib/languageList';

/** 快速筛选プリセット。patch の状態値は内部値のまま（表示のみ翻訳）。 */
const QUICK_FILTERS: { labelKey: string; patch: RecordsQuery }[] = [
  { labelKey: 'export.quickAll', patch: {} },
  { labelKey: 'export.quickReviewed', patch: { dataStatus: 'reviewed' } },
  { labelKey: 'export.quickVerified', patch: { dataStatus: 'verified' } },
  { labelKey: 'export.quickGps', patch: { hasGps: true } },
  { labelKey: 'export.quickPhotos', patch: { hasPhoto: true } },
];

// 导出ファイル名（データ側の規約なので言語によらず固定）。
const stamp = () => {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}` +
    `_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
};

const fmtSize = (n: number) =>
  n >= 1024 ** 3 ? `${(n / 1024 ** 3).toFixed(2)} GB`
  : n >= 1024 ** 2 ? `${(n / 1024 ** 2).toFixed(1)} MB`
  : `${Math.ceil(n / 1024)} KB`;

/** Blob をブラウザ下载として保存する。 */
const saveBlob = (blob: Blob, name: string) => {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
};

/** バックエンドの導出ジョブ 1 本を管理する（進捗ポーリング・取消）。 */
function useExportJob() {
  const [job, setJob] = useState<ExportJobStatus | null>(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopPolling = useCallback(() => {
    if (timer.current != null) {
      clearInterval(timer.current);
      timer.current = null;
    }
  }, []);
  useEffect(() => stopPolling, [stopPolling]);

  const start = async (kickoff: () => Promise<{ jobId: string }>) => {
    setStarting(true);
    setError(null);
    setJob(null);
    try {
      const { jobId } = await kickoff();
      timer.current = setInterval(async () => {
        try {
          const st = await getExportJob(jobId);
          setJob(st);
          if (st.status !== 'running') stopPolling();
        } catch {
          stopPolling();
        }
      }, 700);
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setStarting(false);
    }
  };

  const cancel = async () => {
    if (job && job.status === 'running') await cancelExportJob(job.id);
  };

  return { job, starting, error, start, cancel };
}

export default function ExportPage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [total, setTotal] = useState<number | null>(null);
  const [countError, setCountError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [done, setDone] = useState<string | null>(null); // CSV 保存ファイル名
  const [exportError, setExportError] = useState<string | null>(null);
  const [geoProps, setGeoProps] = useState<'minimal' | 'full'>('minimal');
  const [photosContent, setPhotosContent] =
    useState<'crop' | 'source' | 'both'>('both');
  const [photosNaming, setPhotosNaming] =
    useState<'signid' | 'displayid' | 'original'>('original');
  const options = useFilterOptions();
  const packageJob = useExportJob();
  const photosJob = useExportJob();

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

  const doExportCsv = async () => {
    setExporting(true);
    setExportError(null);
    setDone(null);
    try {
      const blob = await exportRecordsCsv(filters);
      const name = `llmap_export_${stamp()}.csv`;
      saveBlob(blob, name);
      setDone(name);
    } catch (e: unknown) {
      setExportError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setExporting(false);
    }
  };

  const doExportGeoJson = async () => {
    setExportError(null);
    try {
      const blob = await exportGeoJson(filters, geoProps);
      saveBlob(blob, `llmap_export_${stamp()}.geojson`);
    } catch (e: unknown) {
      setExportError(e instanceof ApiError ? e.message : String(e));
    }
  };

  /** ジョブの進捗・結果表示（Dataset Package / 写真 ZIP 共通）。 */
  const jobStatus = (jc: ReturnType<typeof useExportJob>) => (
    <>
      {jc.error && (
        <div className="error-box" style={{ marginTop: 8 }}>
          <div className="hint">{jc.error}</div>
        </div>
      )}
      {jc.job?.status === 'running' && (
        <div className="muted" style={{ marginTop: 8, display: 'flex', gap: 8, alignItems: 'center' }}>
          <span>{t('export.progress', { done: jc.job.done, total: jc.job.total })}</span>
          <button className="btn" onClick={jc.cancel}>{t('common.cancel')}</button>
        </div>
      )}
      {jc.job?.status === 'done' && (
        <div className="ok-box" style={{ marginTop: 8 }}>
          {t('export.jobDone', {
            name: jc.job.fileName, size: fmtSize(jc.job.sizeBytes),
          })}{' '}
          <a className="btn" href={exportJobDownloadUrl(jc.job.id)}>
            {t('export.download')}
          </a>
          {/* zip はこのパスに既に生成済み（導出目录設定の可視化）。
              桌面版なら再ダウンロード不要でそのまま開ける。 */}
          {jc.job.path && (
            <div className="muted" style={{ marginTop: 6, fontSize: 12 }}>
              {t('export.savedTo')}: <code>{jc.job.path}</code>
            </div>
          )}
        </div>
      )}
      {jc.job?.status === 'cancelled' && (
        <div className="muted" style={{ marginTop: 8 }}>{t('export.jobCancelled')}</div>
      )}
      {jc.job?.status === 'error' && (
        <div className="error-box" style={{ marginTop: 8 }}>
          <strong>{t('export.failed')}</strong>
          <div className="hint">{jc.job.error}</div>
        </div>
      )}
    </>
  );

  const sel = (
    label: string,
    value: string,
    opts: { value: string; label: string }[],
    onChange: (v: string) => void,
  ) => (
    <label className="filter-field">
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        {opts.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </label>
  );

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
          languages: languageFilterValues(options.schema?.enums['主要言語']),
          areas: options.areas,
          collectors: options.collectors,
          datasets: options.datasets,
        }}
        schemaEnums={options.schema?.enums}
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

      {/* 导出摘要（CSV 直下载） */}
      <div className="card export-summary">
        <div>
          <div className="label muted">{t('export.matching')}</div>
          <div className="value">{total != null ? total : '—'}</div>
        </div>
        <button
          className="btn primary"
          disabled={exporting || total === 0 || total == null}
          onClick={doExportCsv}
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

      {/* フォーマット別の導出カード */}
      <h3 className="detail-section" style={{ marginTop: 22 }}>{t('export.formats')}</h3>
      <div className="format-grid">
        {/* Dataset Package（ジョブ式・進捗つき） */}
        <div className="card format-card">
          <div className="format-head">
            <strong>{t('export.formatDatasetTitle')}</strong>
            <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
              {t('export.available')}
            </span>
          </div>
          <p className="muted" style={{ margin: '6px 0 8px', fontSize: 12.5 }}>
            {t('export.formatDatasetDesc')}
          </p>
          <button
            className="btn primary"
            disabled={packageJob.starting || packageJob.job?.status === 'running' || !total}
            onClick={() => packageJob.start(() => startPackageExport(filters))}
          >
            {t('export.start')}
          </button>
          {jobStatus(packageJob)}
        </div>

        {/* GeoJSON（同期下载） */}
        <div className="card format-card">
          <div className="format-head">
            <strong>{t('export.formatGeojsonTitle')}</strong>
            <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
              {t('export.available')}
            </span>
          </div>
          <p className="muted" style={{ margin: '6px 0 8px', fontSize: 12.5 }}>
            {t('export.formatGeojsonDesc')} {t('export.geojsonNote')}
          </p>
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', flexWrap: 'wrap' }}>
            {sel(t('export.propsLabel'), geoProps, [
              { value: 'minimal', label: t('export.propsMinimal') },
              { value: 'full', label: t('export.propsFull') },
            ], (v) => setGeoProps(v as 'minimal' | 'full'))}
            <button className="btn primary" disabled={!total} onClick={doExportGeoJson}>
              {t('export.start')}
            </button>
          </div>
        </div>

        {/* 写真 ZIP（ジョブ式・進捗つき） */}
        <div className="card format-card">
          <div className="format-head">
            <strong>{t('export.formatPhotosTitle')}</strong>
            <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
              {t('export.available')}
            </span>
          </div>
          <p className="muted" style={{ margin: '6px 0 8px', fontSize: 12.5 }}>
            {t('export.formatPhotosDesc')} {t('export.dedupNote')}
          </p>
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', flexWrap: 'wrap' }}>
            {sel(t('export.contentLabel'), photosContent, [
              { value: 'both', label: t('export.contentBoth') },
              { value: 'crop', label: t('export.contentCrop') },
              { value: 'source', label: t('export.contentSource') },
            ], (v) => setPhotosContent(v as typeof photosContent))}
            {sel(t('export.namingLabel'), photosNaming, [
              { value: 'original', label: t('export.namingOriginal') },
              { value: 'signid', label: t('export.namingSignId') },
              { value: 'displayid', label: t('export.namingDisplayId') },
            ], (v) => setPhotosNaming(v as typeof photosNaming))}
            <button
              className="btn primary"
              disabled={photosJob.starting || photosJob.job?.status === 'running' || !total}
              onClick={() => photosJob.start(
                () => startPhotosExport(filters, photosContent, photosNaming))}
            >
              {t('export.start')}
            </button>
          </div>
          {jobStatus(photosJob)}
        </div>

        {/* CSV（情報カード。実行は上の摘要から） */}
        <div className="card format-card">
          <div className="format-head">
            <strong>{t('export.formatCsvTitle')}</strong>
            <span className="badge" style={{ color: '#1e9e6a', borderColor: '#1e9e6a55', background: '#1e9e6a14' }}>
              {t('export.available')}
            </span>
          </div>
          <p className="muted" style={{ margin: '6px 0 0', fontSize: 12.5 }}>
            {t('export.formatCsvDesc')}
          </p>
        </div>
      </div>
    </>
  );
}
