import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  ApiError, cancelExportJob, exportGeoJson, exportJobDownloadUrl,
  exportRecordsCsv, getConfig, getExportJob, getRecords,
  previewPhotosExport, previewPhotosSplit, startPackageExport, startPhotosExport,
  startPhotosSplitExport,
} from '../api/client';
import type {
  AppConfig, ExportJobStatus, PhotosExportPreview, PhotosSplitPreview, RecordsQuery,
} from '../api/types';
import ScopeBanner from '../components/ScopeBanner';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters, { scopeQuery, type ScopeKind } from '../hooks/useSharedFilters';
import { enumLabel } from '../lib/enumLabels';

// 分類照片に使える枚挙字段（定義表のグループ順）。
const SPLIT_FIELDS = [
  '文字性', '主要言語', '補助言語', '装飾の言語', '文字体系', '多言語関係',
  '担体類型', '放置位置', '空間階層', '時間性', '可読性', '重ね書き',
  '設置主体', 'ディスコース類型', '製作品質',
];

// 導出の優先順（よく使う順）: 分類照片 → 完全データ包 → 照片と CSV → 地図データ。
type Tab = 'split' | 'package' | 'photos' | 'geo';
const TABS: Tab[] = ['split', 'package', 'photos', 'geo'];
type Content = 'crop' | 'source' | 'both';
type Naming = 'signid' | 'displayid' | 'original';
type SplitMode = 'single' | 'combo';

interface Prefs {
  tab: Tab;
  splitField: string;
  splitMode: SplitMode;
  content: Content;
  naming: Naming;
  outputDir: string;
  geoProps: 'minimal' | 'full';
}
const PREFS_KEY = 'llmap.exportPrefs';
const DEFAULT_PREFS: Prefs = {
  tab: 'split', splitField: '主要言語', splitMode: 'single',
  content: 'crop', naming: 'original', outputDir: '', geoProps: 'minimal',
};
function loadPrefs(): Prefs {
  try {
    return { ...DEFAULT_PREFS, ...JSON.parse(localStorage.getItem(PREFS_KEY) || '{}') };
  } catch {
    return DEFAULT_PREFS;
  }
}

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

  const running = starting || job?.status === 'running';
  return { job, starting, running, error, start, cancel };
}

/** 胶囊の選択（seg）。 */
function Seg<T extends string>({ value, options, onChange, label }: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (v: T) => void;
  label: string;
}) {
  return (
    <div className="seg" role="radiogroup" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} type="button" role="radio" aria-checked={value === o.value}
          className={value === o.value ? 'on' : ''} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** 導出ジョブの進捗・結果・失敗の表示（分類照片 / データ包 / 照片 ZIP 共通）。 */
function JobStatus({ job }: { job: ReturnType<typeof useExportJob> }) {
  const { t } = useTranslation();
  const st = job.job;
  return (
    <>
      {job.error && <div className="error-box"><div className="hint">{job.error}</div></div>}
      {st?.status === 'running' && (
        <div className="job-row">
          <span className="job-bar"><i style={{ width: `${st.total ? (st.done / st.total) * 100 : 0}%` }} /></span>
          <span className="mono">{st.done} / {st.total}</span>
          <button className="btn ghost" onClick={job.cancel}>{t('common.cancel')}</button>
        </div>
      )}
      {st?.status === 'done' && (
        <div className="ok-box">
          <span className="mono">{st.fileName}</span> · {fmtSize(st.sizeBytes)}
          {st.kind === 'photos_split'
            ? <> · {t('export.splitZips', { n: st.report?.zipCount ?? 0 })}</>
            : <> · <a href={exportJobDownloadUrl(st.id)}>{t('export.download')}</a></>}
          {st.path && <div className="mono path">{st.path}</div>}
        </div>
      )}
      {st?.status === 'cancelled' && <div className="muted">{t('export.jobCancelled')}</div>}
      {st?.status === 'error' && (
        <div className="error-box">
          <strong>{t('export.failed')}</strong>
          <div className="hint">{st.error}</div>
        </div>
      )}
    </>
  );
}

export default function ExportPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const shared = useSharedFilters();
  const options = useFilterOptions();

  // 範囲: 資料庫の筛选結果（既定）か、手動で選んだ記録か。
  const [scope, setScope] = useState<ScopeKind>(
    () => (params.get('scope') === 'sel' && shared.selection.length ? 'sel' : 'db'));
  useEffect(() => {
    if (params.get('scope')) setParams({}, { replace: true });
  }, [params, setParams]);
  const filters: RecordsQuery = scopeQuery(scope, shared.filters, shared.selection);
  const filtersKey = JSON.stringify(filters);

  const [prefs, setPrefs] = useState<Prefs>(loadPrefs);
  const setPref = <K extends keyof Prefs>(k: K, v: Prefs[K]) =>
    setPrefs((p) => ({ ...p, [k]: v }));
  useEffect(() => {
    try { localStorage.setItem(PREFS_KEY, JSON.stringify(prefs)); } catch { /* 記憶できなくても動く */ }
  }, [prefs]);
  const dir = prefs.outputDir.trim() || undefined;

  const [total, setTotal] = useState<number | null>(null);
  const [countError, setCountError] = useState<string | null>(null);
  const [cfg, setCfg] = useState<AppConfig | null>(null);
  useEffect(() => { getConfig().then(setCfg).catch(() => {}); }, []);

  // 範囲の件数。
  useEffect(() => {
    setCountError(null);
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => setTotal(r.total))
      .catch((e: unknown) => {
        setTotal(null);
        setCountError(e instanceof ApiError ? e.message : String(e));
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtersKey]);

  // 分類照片の事前集計（字段・方式・内容・命名・範囲に追従）。
  const multiField = (f: string) => !!options.schema?.multi_fields?.includes(f);
  const [split, setSplit] = useState<PhotosSplitPreview | null>(null);
  const [splitError, setSplitError] = useState<string | null>(null);
  useEffect(() => {
    if (prefs.tab !== 'split' || !prefs.splitField) return;
    let stale = false;
    setSplit(null);
    setSplitError(null);
    previewPhotosSplit(filters, prefs.content, prefs.naming, prefs.splitField, prefs.splitMode)
      .then((p) => { if (!stale) setSplit(p); })
      .catch((e: unknown) => { if (!stale) setSplitError(e instanceof ApiError ? e.message : String(e)); });
    return () => { stale = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtersKey, prefs.tab, prefs.splitField, prefs.splitMode, prefs.content, prefs.naming]);

  // 照片 ZIP（分類なし）の事前集計。
  const [photosPv, setPhotosPv] = useState<PhotosExportPreview | null>(null);
  useEffect(() => {
    if (prefs.tab !== 'photos') return;
    let stale = false;
    setPhotosPv(null);
    previewPhotosExport(filters, prefs.content)
      .then((p) => { if (!stale) setPhotosPv(p); })
      .catch(() => { if (!stale) setPhotosPv(null); });
    return () => { stale = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtersKey, prefs.tab, prefs.content]);

  const splitJob = useExportJob();
  const packageJob = useExportJob();
  const photosJob = useExportJob();

  // 同期型（CSV / GeoJSON）の結果。
  const [syncBusy, setSyncBusy] = useState(false);
  const [syncDone, setSyncDone] = useState<string | null>(null);
  const [syncError, setSyncError] = useState<string | null>(null);
  useEffect(() => { setSyncDone(null); setSyncError(null); }, [filtersKey, prefs.tab]);
  const download = async (kind: 'csv' | 'geojson') => {
    setSyncBusy(true);
    setSyncDone(null);
    setSyncError(null);
    try {
      const name = `llmap_export_${stamp()}.${kind}`;
      const blob = kind === 'csv'
        ? await exportRecordsCsv(filters)
        : await exportGeoJson(filters, prefs.geoProps);
      saveBlob(blob, name);
      setSyncDone(name);
    } catch (e: unknown) {
      setSyncError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setSyncBusy(false);
    }
  };

  const fieldLabel = (f: string) => t(`fields.${f}`, { defaultValue: f });
  const splitFields = SPLIT_FIELDS.filter((k) =>
    options.schema?.enums[k]?.length && ((options.fieldStats?.[k] ?? 1) > 0 || k === prefs.splitField));
  const isMulti = multiField(prefs.splitField);
  const valueLabel = (v: string) => v.split('+').map((x) => enumLabel(t, x)).join(' + ');
  const missingSum = split?.groups.reduce((a, g) => a + g.missing, 0) ?? 0;
  const zipCount = split?.groups.filter((g) => g.records > 0).length ?? 0;
  const empty = !total;

  const contentSeg = (
    <div className="exp-row">
      <span className="exp-k">{t('export.contentLabel')}</span>
      <Seg<Content> label={t('export.contentLabel')} value={prefs.content}
        onChange={(v) => setPref('content', v)} options={[
          { value: 'crop', label: t('export.contentCrop') },
          { value: 'source', label: t('export.contentSource') },
          { value: 'both', label: t('export.contentBoth') },
        ]} />
    </div>
  );
  const moreOptions = (withNaming: boolean) => (
    <details className="exp-more">
      <summary>{t('export.moreOptions')}</summary>
      <div className="exp-more-body">
        {withNaming && (
          <label className="opt">
            <span>{t('export.namingLabel')}</span>
            <select value={prefs.naming} onChange={(e) => setPref('naming', e.target.value as Naming)}>
              <option value="original">{t('export.namingOriginal')}</option>
              <option value="signid">{t('export.namingSignId')}</option>
              <option value="displayid">{t('export.namingDisplayId')}</option>
            </select>
          </label>
        )}
        <label className="opt">
          <span>{t('export.outputDir')}</span>
          <input type="text" value={prefs.outputDir} placeholder={cfg?.effectiveExportDir ?? ''}
            onChange={(e) => setPref('outputDir', e.target.value)} />
        </label>
      </div>
    </details>
  );

  return (
    <>
      <div className="page-head compact">
        <h1>{t('export.title')}</h1>
      </div>

      <ScopeBanner
        filters={filters}
        datasets={options.datasets}
        count={total}
        onReset={scope === 'db' ? () => navigate('/database') : undefined}
        resetLabel={t('export.adjustScope')}
      />
      {shared.selection.length > 0 && (
        <div className="note-line">
          {scope === 'db'
            ? <>{t('export.selectionAvailable', { n: shared.selection.length })}
              <button type="button" className="link-btn" onClick={() => setScope('sel')}>
                {t('export.useSelection')}
              </button></>
            : <button type="button" className="link-btn" onClick={() => setScope('db')}>
              {t('export.useFilter')}
            </button>}
        </div>
      )}

      {countError && (
        <div className="error-box">
          <strong>{t('export.countError')}</strong>
          <div className="hint">{countError}</div>
        </div>
      )}

      <div className="exp-tabs" role="tablist">
        {TABS.map((k, i) => (
          <button key={k} type="button" role="tab" aria-selected={prefs.tab === k}
            className={`exp-tab${prefs.tab === k ? ' on' : ''}`} onClick={() => setPref('tab', k)}>
            <b>{String(i + 1).padStart(2, '0')}</b>
            <span>{t(`export.tab.${k}`)}</span>
            <small>{t(`export.tabDesc.${k}`)}</small>
          </button>
        ))}
      </div>

      {/* ── 01 分類照片 ── */}
      {prefs.tab === 'split' && (
        <section className="card exp-panel">
          <div className="exp-row">
            <span className="exp-k">{t('export.splitField')}</span>
            <select className="exp-select" value={prefs.splitField}
              onChange={(e) => setPref('splitField', e.target.value)}>
              {splitFields.map((k) => <option key={k} value={k}>{fieldLabel(k)}</option>)}
            </select>
            {isMulti && (
              <Seg<SplitMode> label={t('export.splitMode')} value={prefs.splitMode}
                onChange={(v) => setPref('splitMode', v)} options={[
                  { value: 'single', label: t('export.modeSingle') },
                  { value: 'combo', label: t('export.modeCombo') },
                ]} />
            )}
          </div>
          <p className="exp-hint">
            {isMulti
              ? t(prefs.splitMode === 'combo' ? 'export.modeComboHint' : 'export.modeSingleHint',
                { field: fieldLabel(prefs.splitField) })
              : t('export.singleValueHint', { field: fieldLabel(prefs.splitField) })}
          </p>
          {contentSeg}

          {splitError && <div className="error-box"><div className="hint">{splitError}</div></div>}
          {!split && !splitError && <div className="muted">{t('export.previewing')}</div>}
          {split && (
            <>
              <table className="exp-table">
                <thead>
                  <tr>
                    <th>{t('export.colGroup')}</th>
                    <th>{t('export.colZip')}</th>
                    <th className="num">{t('export.colRecords')}</th>
                    <th className="num">{t('export.colFiles')}</th>
                    <th className="num">{t('export.colMissing')}</th>
                  </tr>
                </thead>
                <tbody>
                  {split.groups.map((g) => (
                    <tr key={g.zipName}>
                      <td>{valueLabel(g.value)}</td>
                      <td className="mono dim">{g.zipName}</td>
                      <td className="num mono">{g.records}</td>
                      <td className="num mono">{g.files}</td>
                      <td className={`num mono${g.missing ? ' warn' : ' dim'}`}>{g.missing}</td>
                    </tr>
                  ))}
                  {split.groups.length === 0 && (
                    <tr><td colSpan={5} className="muted">{t('export.noGroups')}</td></tr>
                  )}
                </tbody>
              </table>
              {/* 件数の読み方: 重複・未分類・欠落を言葉で説明する。 */}
              <ul className="exp-notes">
                <li>{t('export.sumLine', {
                  records: split.recordCount, zips: zipCount, files: split.totalFiles,
                })}</li>
                {split.duplicateRecords > 0 && (
                  <li>{t('export.dupLine', { n: split.duplicateRecords })}</li>
                )}
                {isMulti && prefs.splitMode === 'combo' && (
                  <li>{t('export.comboLine')}</li>
                )}
                {split.unclassified > 0 && (
                  <li className="warn">{t('export.unclassifiedLine', {
                    n: split.unclassified, field: fieldLabel(prefs.splitField),
                  })}</li>
                )}
                {missingSum > 0 && <li className="warn">{t('export.missingLine', { n: missingSum })}</li>}
                <li className="dim">{t('export.dedupLine')}</li>
              </ul>
            </>
          )}
          {moreOptions(true)}
          <div className="exp-actions">
            <button className="btn primary" disabled={empty || !zipCount || splitJob.running}
              onClick={() => void splitJob.start(() => startPhotosSplitExport(
                filters, prefs.content, prefs.naming, prefs.splitField, dir, prefs.splitMode))}>
              {splitJob.running ? t('export.exporting')
                : split ? t('export.runSplit', { zips: zipCount, files: split.totalFiles }) : t('export.start')}
            </button>
          </div>
          <JobStatus job={splitJob} />
          {splitJob.job?.status === 'done' && splitJob.job.report?.zips && (
            <table className="exp-table compact">
              <tbody>
                {splitJob.job.report.zips.map((z) => (
                  <tr key={z.zipName}>
                    <td className="mono">{z.zipName}</td>
                    <td className="num mono">{t('export.zipRecords', { n: z.records })}</td>
                    <td className="num mono">{t('export.zipFiles', { n: z.filesAdded })}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      )}

      {/* ── 02 完全データ包 ── */}
      {prefs.tab === 'package' && (
        <section className="card exp-panel">
          <p className="exp-hint">{t('export.packageDesc')}</p>
          {moreOptions(false)}
          <div className="exp-actions">
            <button className="btn primary" disabled={empty || packageJob.running}
              onClick={() => void packageJob.start(() => startPackageExport(filters, dir))}>
              {packageJob.running ? t('export.exporting') : t('export.runPackage', { n: total ?? 0 })}
            </button>
          </div>
          <JobStatus job={packageJob} />
        </section>
      )}

      {/* ── 03 照片と CSV ── */}
      {prefs.tab === 'photos' && (
        <section className="card exp-panel">
          <h3 className="exp-h">{t('export.photosZipTitle')}</h3>
          <p className="exp-hint">{t('export.photosZipDesc')}</p>
          {contentSeg}
          {photosPv && (
            <ul className="exp-notes">
              <li>{t('export.photosPvLine', {
                crop: photosPv.cropFiles, source: photosPv.sourceFiles, files: photosPv.totalFiles,
              })}</li>
              {photosPv.missingCount > 0 && (
                <li className="warn">{t('export.missingLine', { n: photosPv.missingCount })}</li>
              )}
            </ul>
          )}
          {moreOptions(true)}
          <div className="exp-actions">
            <button className="btn primary" disabled={empty || photosJob.running}
              onClick={() => void photosJob.start(() =>
                startPhotosExport(filters, prefs.content, prefs.naming, dir))}>
              {photosJob.running ? t('export.exporting')
                : photosPv ? t('export.runPhotos', { n: photosPv.totalFiles }) : t('export.start')}
            </button>
          </div>
          <JobStatus job={photosJob} />

          <hr className="exp-sep" />
          <h3 className="exp-h">CSV</h3>
          <p className="exp-hint">{t('export.csvNote')}</p>
          <div className="exp-actions">
            <button className="btn" disabled={empty || syncBusy} onClick={() => void download('csv')}>
              {t('export.runCsv', { n: total ?? 0 })}
            </button>
          </div>
        </section>
      )}

      {/* ── 04 地図データ ── */}
      {prefs.tab === 'geo' && (
        <section className="card exp-panel">
          <p className="exp-hint">{t('export.geoDesc')}</p>
          <div className="exp-row">
            <span className="exp-k">{t('export.propsLabel')}</span>
            <Seg<'minimal' | 'full'> label={t('export.propsLabel')} value={prefs.geoProps}
              onChange={(v) => setPref('geoProps', v)} options={[
                { value: 'minimal', label: t('export.propsMinimal') },
                { value: 'full', label: t('export.propsFull') },
              ]} />
          </div>
          <div className="exp-actions">
            <button className="btn primary" disabled={empty || syncBusy} onClick={() => void download('geojson')}>
              {t('export.runGeo')}
            </button>
          </div>
        </section>
      )}

      {(prefs.tab === 'photos' || prefs.tab === 'geo') && (
        <>
          {syncDone && <div className="ok-box"><span className="mono">{syncDone}</span></div>}
          {syncError && (
            <div className="error-box">
              <strong>{t('export.failed')}</strong>
              <div className="hint">{syncError}</div>
            </div>
          )}
        </>
      )}
    </>
  );
}
