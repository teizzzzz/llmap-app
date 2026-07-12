import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import {
  API_BASE_URL, ApiError, IS_DESKTOP, getRecords, getStatsSummary,
} from '../api/client';
import type { StatsSummary } from '../api/types';
import { PENDING_STATUSES } from '../reviewStatus';

/** 分布の横棒リスト（純CSS・図表ライブラリ不使用）。
    labelOf は表示ラベル変換（状態値の翻訳用）。データキー自体は変えない。 */
function BarList({
  title,
  counts,
  labelOf,
}: {
  title: string;
  counts: Record<string, number>;
  labelOf?: (key: string) => string;
}) {
  const { t } = useTranslation();
  const entries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  const max = entries.length ? entries[0][1] : 0;
  return (
    <div className="card count-card">
      <h3>{title}</h3>
      {entries.length === 0 ? (
        <div className="muted">{t('dashboard.noData')}</div>
      ) : (
        entries.map(([k, v]) => {
          const label = labelOf ? labelOf(k) : k;
          return (
            <div key={k} className="bar-row">
              <span className="bar-label" title={label}>{label}</span>
              <span className="bar-track">
                <span
                  className="bar-fill"
                  style={{ width: `${max ? Math.max(4, (v / max) * 100) : 0}%` }}
                />
              </span>
              <span className="bar-n">{v}</span>
            </div>
          );
        })
      )}
    </div>
  );
}

function Tile({ label, value, to }: { label: string; value: number | string; to?: string }) {
  const body = (
    <>
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </>
  );
  return to ? (
    <Link className="card stat-tile stat-link" to={to}>{body}</Link>
  ) : (
    <div className="card stat-tile">{body}</div>
  );
}

export default function DashboardPage() {
  const { t } = useTranslation();
  const [stats, setStats] = useState<StatsSummary | null>(null);
  const [withGps, setWithGps] = useState<number | null>(null);
  const [withPhoto, setWithPhoto] = useState<number | null>(null);
  const [withSource, setWithSource] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getStatsSummary()
      .then(setStats)
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
    // GPS/写真の件数は既存 /records の hasX 筛选から導出（backend 変更なし）。
    const count = (q: object, set: (n: number) => void) =>
      getRecords({ ...q, page: 1, pageSize: 1 }).then((r) => set(r.total)).catch(() => {});
    count({ hasGps: true }, setWithGps);
    count({ hasPhoto: true }, setWithPhoto);
    count({ hasSourcePhoto: true }, setWithSource);
  }, []);

  const ds = stats?.dataStatusCounts ?? {};
  const sum = (keys: string[]) => keys.reduce((a, k) => a + (ds[k] ?? 0), 0);
  const waiting = sum(PENDING_STATUSES);
  const na = (v: number | null) => (v == null ? '—' : v);
  // 状態値・モード値の分布は表示ラベルのみ翻訳（キーは内部値のまま）。
  const statusLabel = (k: string) => t(`status.${k}`, { defaultValue: k });

  return (
    <>
      <div className="page-header">
        <h1>{t('dashboard.title')}</h1>
        <p>{t('dashboard.subtitle')}</p>
      </div>

      {loading && <div className="muted">{t('dashboard.loading')}</div>}

      {error && (
        <div className="error-box">
          <strong>{t('dashboard.statsError')}</strong>
          <div className="hint">
            {error}
            <br />
            {/* 桌面版は backend を shell が自動起動する — uvicorn の案内は
                Web/開発モードのときだけ出す。 */}
            {!IS_DESKTOP && (
              <>
                {t('dashboard.startBackendHint')}{' '}
                <code>cd backend && uvicorn app.main:app --port 8000</code>
                <br />
              </>
            )}
            {t('dashboard.currentUrl')}: <code>{API_BASE_URL}</code>
            {!IS_DESKTOP && (
              <> ({t('dashboard.configurableVia')}: <code>VITE_API_BASE_URL</code>)</>
            )}
          </div>
        </div>
      )}

      {stats && (
        <>
          {/* 1. Overview */}
          <div className="stat-grid">
            <Tile label={t('dashboard.totalRecords')} value={stats.recordCount} to="/database" />
            <Tile label={t('dashboard.datasets')} value={stats.datasetCount} />
            <Tile label={t('dashboard.withGps')} value={na(withGps)} to="/map" />
            <Tile label={t('dashboard.waitingReview')} value={waiting} to="/review" />
            <Tile label={t('dashboard.reviewed')} value={ds['reviewed'] ?? 0} />
            <Tile label={t('dashboard.verified')} value={ds['verified'] ?? 0} />
            <Tile label={t('dashboard.photos')} value={stats.photoCount} />
            <Tile label={t('dashboard.sourcePhotos')} value={stats.sourcePhotoCount} />
          </div>

          {/* 2-5. 分布 */}
          <div className="count-grid">
            <BarList title={t('dashboard.byDataStatus')} counts={stats.dataStatusCounts}
              labelOf={statusLabel} />
            <BarList title={t('dashboard.byEntryMode')} counts={stats.entryModeCounts}
              labelOf={statusLabel} />
            <BarList title={t('dashboard.byMainLanguage')} counts={stats.mainLanguageCounts} />
            <BarList title={t('dashboard.byArea')} counts={stats.areaCounts} />
            <BarList title={t('dashboard.byCollector')} counts={stats.collectorCounts} />

            {/* 6. データ品質 */}
            <div className="card count-card">
              <h3>{t('dashboard.dataQuality')}</h3>
              <div className="count-row">
                <span>{t('dashboard.missingPhotos')}</span>
                <span className="n">{stats.missingPhotoCount}</span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.missingSourcePhotos')}</span>
                <span className="n">{stats.missingSourcePhotoCount}</span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.withoutGps')}</span>
                <span className="n">
                  {withGps == null ? '—' : stats.recordCount - withGps}
                </span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.withoutPhoto')}</span>
                <span className="n">
                  {withPhoto == null ? '—' : stats.recordCount - withPhoto}
                </span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.withoutSourcePhoto')}</span>
                <span className="n">
                  {withSource == null ? '—' : stats.recordCount - withSource}
                </span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.unknownEntryMode')}</span>
                <span className="n">{stats.entryModeCounts['unknown'] ?? 0}</span>
              </div>
              <div className="count-row">
                <span>{t('dashboard.unknownDataStatus')}</span>
                <span className="n">{ds['unknown'] ?? 0}</span>
              </div>
            </div>
          </div>

          {/* 7. 快捷入口 */}
          <h3 className="detail-section" style={{ marginTop: 20 }}>{t('dashboard.shortcuts')}</h3>
          <div className="shortcut-row">
            <Link className="btn" to="/database">{t('dashboard.openDatabase')}</Link>
            <Link className="btn" to="/review">{t('dashboard.openReview')}</Link>
            <Link className="btn" to="/map">{t('dashboard.openMap')}</Link>
            <Link className="btn" to="/export">{t('dashboard.exportData')}</Link>
            <Link className="btn primary" to="/database">{t('dashboard.importDataset')}</Link>
          </div>
        </>
      )}
    </>
  );
}
