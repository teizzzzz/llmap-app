import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  ApiError, cancelExportJob, exportGeoJson, exportJobDownloadUrl,
  exportRecordsCsv, getConfig, getExportJob, getRecords,
  previewPhotosExport, startPackageExport, startPhotosExport,
  startPhotosSplitExport,
} from '../api/client';
import type { AppConfig, ExportJobStatus, PhotosExportPreview } from '../api/types';
import RecordsFilters from '../components/database/RecordsFilters';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters from '../hooks/useSharedFilters';
import { languageFilterValues } from '../lib/languageList';

// 写真 ZIP の字段別分包に出す枚挙字段（定義表のグループ順）。
const SPLIT_FIELDS = [
  '文字性', '主要言語', '補助言語', '装飾の言語', '文字体系', '多言語関係',
  '担体類型', '放置位置', '空間階層', '時間性', '可読性', '重ね書き',
  '設置主体', 'ディスコース類型', '製作品質',
];

type Format = 'photos' | 'package' | 'csv' | 'geojson';
const FORMATS: Format[] = ['photos', 'package', 'csv', 'geojson'];

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

/** 選択肢の小さな縦組み（ラベル＋ select）。 */
function Option({ label, value, options, onChange }: {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <label className="opt">
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </label>
  );
}

export default function ExportPage() {
  const { t } = useTranslation();
  const { filters, patch, clear } = useSharedFilters();
  const [total, setTotal] = useState<number | null>(null);
  const [countError, setCountError] = useState<string | null>(null);
  const [format, setFormat] = useState<Format>('photos');
  const [geoProps, setGeoProps] = useState<'minimal' | 'full'>('minimal');
  const [photosContent, setPhotosContent] = useState<'crop' | 'source' | 'both'>('both');
  const [photosNaming, setPhotosNaming] = useState<'signid' | 'displayid' | 'original'>('original');
  // 字段別分包（'' = 分包しない = 1 本の zip）。
  const [photosSplitField, setPhotosSplitField] = useState('');
  // 導出先の一時指定（空 = 設定の既定目录）。設定自体は変更しない。
  const [outputDir, setOutputDir] = useState('');
  const [cfg, setCfg] = useState<AppConfig | null>(null);
  const [preview, setPreview] = useState<PhotosExportPreview | null>(null);
  // 同期型（CSV / GeoJSON）の結果。
  const [syncBusy, setSyncBusy] = useState(false);
  const [syncDone, setSyncDone] = useState<string | null>(null);
  const [syncError, setSyncError] = useState<string | null>(null);
  const options = useFilterOptions();
  const packageJob = useExportJob();
  const photosJob = useExportJob();

  useEffect(() => { getConfig().then(setCfg).catch(() => {}); }, []);

  // 写真 ZIP の事前集計（筛选条件・内容選択に追従）。
  useEffect(() => {
    let stale = false;
    setPreview(null);
    previewPhotosExport(filters, photosContent)
      .then((p) => { if (!stale) setPreview(p); })
      .catch(() => { if (!stale) setPreview(null); });
    return () => { stale = true; };
  }, [filters, photosContent]);

  // 筛选後の件数。pageSize=1 で total だけ取得する。
  useEffect(() => {
    setCountError(null);
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => setTotal(r.total))
      .catch((e: unknown) => {
        setTotal(null);
        setCountError(e instanceof ApiError ? e.message : String(e));
      });
  }, [filters]);
  useEffect(() => { setSyncDone(null); setSyncError(null); }, [filters, format]);

  const dir = outputDir.trim() || undefined;
  const job = format === 'photos' ? photosJob : format === 'package' ? packageJob : null;
  const running = !!job && (job.starting || job.job?.status === 'running');

  const run = async () => {
    if (format === 'photos') {
      void photosJob.start(() => photosSplitField
        ? startPhotosSplitExport(filters, photosContent, photosNaming, photosSplitField, dir)
        : startPhotosExport(filters, photosContent, photosNaming, dir));
      return;
    }
    if (format === 'package') {
      void packageJob.start(() => startPackageExport(filters, dir));
      return;
    }
    setSyncBusy(true);
    setSyncDone(null);
    setSyncError(null);
    try {
      const name = `llmap_export_${stamp()}.${format === 'csv' ? 'csv' : 'geojson'}`;
      const blob = format === 'csv'
        ? await exportRecordsCsv(filters)
        : await exportGeoJson(filters, geoProps);
      saveBlob(blob, name);
      setSyncDone(name);
    } catch (e: unknown) {
      setSyncError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setSyncBusy(false);
    }
  };

  const splitOptions = [
    { value: '', label: t('export.splitNone') },
    ...SPLIT_FIELDS
      .filter((k) => options.schema?.enums[k]?.length && (options.fieldStats?.[k] ?? 1) > 0)
      .map((k) => ({ value: k, label: t(`fields.${k}`, { defaultValue: k }) })),
  ];

  return (
    <>
      <div className="page-head">
        <h1>{t('export.title')}<span className="page-count">{total ?? ''}</span></h1>
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
        fieldPresence={options.fieldStats}
        total={total}
        onChange={patch}
        onClear={clear}
      />

      {countError && (
        <div className="error-box">
          <strong>{t('export.countError')}</strong>
          <div className="hint">{countError}</div>
        </div>
      )}

      <div className="steps">
        {/* 01 範囲: 筛选結果の内訳 */}
        <section className="step">
          <header><b>01</b><h2>{t('export.stepScope')}</h2></header>
          <div className="step-big">{total ?? '—'}</div>
          {preview && (
            <>
              <div className="dash-row"><span>{t('export.cropFiles')}</span><span className="mono">{preview.cropFiles}</span></div>
              <div className="dash-row"><span>{t('export.sourceFiles')}</span><span className="mono">{preview.sourceFiles}</span></div>
              <div className={`dash-row${preview.missingCount ? '' : ' muted'}`}>
                <span>{t('export.missingFiles')}</span><span className="mono">{preview.missingCount}</span>
              </div>
            </>
          )}
        </section>

        {/* 02 格式 */}
        <section className="step">
          <header><b>02</b><h2>{t('export.stepFormat')}</h2></header>
          <div className="formats" role="radiogroup">
            {FORMATS.map((f) => (
              <button key={f} type="button" role="radio" aria-checked={format === f}
                className={`format${format === f ? ' on' : ''}`} onClick={() => setFormat(f)}>
                <i />{t(`export.format.${f}`)}
              </button>
            ))}
          </div>
        </section>

        {/* 03 選項（形式ごと） */}
        <section className="step">
          <header><b>03</b><h2>{t('export.stepOptions')}</h2></header>
          {format === 'photos' && (
            <>
              <Option label={t('export.contentLabel')} value={photosContent} options={[
                { value: 'both', label: t('export.contentBoth') },
                { value: 'crop', label: t('export.contentCrop') },
                { value: 'source', label: t('export.contentSource') },
              ]} onChange={(v) => setPhotosContent(v as typeof photosContent)} />
              <Option label={t('export.namingLabel')} value={photosNaming} options={[
                { value: 'original', label: t('export.namingOriginal') },
                { value: 'signid', label: t('export.namingSignId') },
                { value: 'displayid', label: t('export.namingDisplayId') },
              ]} onChange={(v) => setPhotosNaming(v as typeof photosNaming)} />
              <Option label={t('export.splitLabel')} value={photosSplitField}
                options={splitOptions} onChange={setPhotosSplitField} />
            </>
          )}
          {format === 'geojson' && (
            <Option label={t('export.propsLabel')} value={geoProps} options={[
              { value: 'minimal', label: t('export.propsMinimal') },
              { value: 'full', label: t('export.propsFull') },
            ]} onChange={(v) => setGeoProps(v as 'minimal' | 'full')} />
          )}
          {(format === 'csv' || format === 'package') && <div className="muted">—</div>}
        </section>

        {/* 04 输出 */}
        <section className="step">
          <header><b>04</b><h2>{t('export.stepOutput')}</h2></header>
          {(format === 'photos' || format === 'package') && (
            <label className="opt">
              <span>{t('export.outputDir')}</span>
              <input type="text" value={outputDir} placeholder={cfg?.effectiveExportDir ?? ''}
                onChange={(e) => setOutputDir(e.target.value)} />
            </label>
          )}
          {format === 'photos' && preview && (
            <div className="step-sum">
              <span className="step-big">{preview.totalFiles}</span>
              <span>{t('export.filesUnit')}</span>
            </div>
          )}
          <span className="spacer-v" />
          <button className="btn primary wide" disabled={running || syncBusy || !total} onClick={run}>
            {running || syncBusy ? t('export.exporting') : t('export.start')}
            <kbd>↵</kbd>
          </button>

          {job?.error && <div className="error-box"><div className="hint">{job.error}</div></div>}
          {job?.job?.status === 'running' && (
            <div className="job-row">
              <span className="mono">{job.job.done} / {job.job.total}</span>
              <button className="btn ghost" onClick={job.cancel}>{t('common.cancel')}</button>
            </div>
          )}
          {job?.job?.status === 'done' && (
            <div className="ok-box">
              <span className="mono">{job.job.fileName}</span> · {fmtSize(job.job.sizeBytes)}
              {job.job.kind === 'photos_split'
                ? <> · {t('export.splitZips', { n: job.job.report?.zipCount ?? 0 })}</>
                : <> · <a href={exportJobDownloadUrl(job.job.id)}>{t('export.download')}</a></>}
              {job.job.path && <div className="mono path">{job.job.path}</div>}
            </div>
          )}
          {job?.job?.status === 'cancelled' && <div className="muted">{t('export.jobCancelled')}</div>}
          {job?.job?.status === 'error' && (
            <div className="error-box">
              <strong>{t('export.failed')}</strong>
              <div className="hint">{job.job.error}</div>
            </div>
          )}
          {syncDone && <div className="ok-box"><span className="mono">{syncDone}</span></div>}
          {syncError && (
            <div className="error-box">
              <strong>{t('export.failed')}</strong>
              <div className="hint">{syncError}</div>
            </div>
          )}
        </section>
      </div>
    </>
  );
}
