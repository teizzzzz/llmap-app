import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { API_BASE_URL, ApiError, getRecords, getStatsSummary } from '../api/client';
import type { StatsSummary } from '../api/types';
import { PENDING_STATUSES } from '../reviewStatus';

/** 分布の横棒リスト（純CSS・図表ライブラリ不使用）。 */
function BarList({ title, counts }: { title: string; counts: Record<string, number> }) {
  const entries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  const max = entries.length ? entries[0][1] : 0;
  return (
    <div className="card count-card">
      <h3>{title}</h3>
      {entries.length === 0 ? (
        <div className="muted">No data yet.</div>
      ) : (
        entries.map(([k, v]) => (
          <div key={k} className="bar-row">
            <span className="bar-label" title={k}>{k}</span>
            <span className="bar-track">
              <span
                className="bar-fill"
                style={{ width: `${max ? Math.max(4, (v / max) * 100) : 0}%` }}
              />
            </span>
            <span className="bar-n">{v}</span>
          </div>
        ))
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

  return (
    <>
      <div className="page-header">
        <h1>Dashboard</h1>
        <p>Overview of the local linguistic landscape database.</p>
      </div>

      {loading && <div className="muted">Loading stats…</div>}

      {error && (
        <div className="error-box">
          <strong>Could not load stats.</strong>
          <div className="hint">
            {error}
            <br />
            Start the backend with: <code>cd backend && uvicorn app.main:app --port 8000</code>
            {' '}(current URL: <code>{API_BASE_URL}</code>, configurable via{' '}
            <code>VITE_API_BASE_URL</code>)
          </div>
        </div>
      )}

      {stats && (
        <>
          {/* 1. Overview */}
          <div className="stat-grid">
            <Tile label="Total records" value={stats.recordCount} to="/database" />
            <Tile label="Datasets" value={stats.datasetCount} />
            <Tile label="Records with GPS" value={na(withGps)} to="/map" />
            <Tile label="Waiting for review" value={waiting} to="/review" />
            <Tile label="Reviewed" value={ds['reviewed'] ?? 0} />
            <Tile label="Verified (research-ready)" value={ds['verified'] ?? 0} />
            <Tile label="Photos" value={stats.photoCount} />
            <Tile label="Source photos" value={stats.sourcePhotoCount} />
          </div>

          {/* 2-5. 分布 */}
          <div className="count-grid">
            <BarList title="By data status" counts={stats.dataStatusCounts} />
            <BarList title="By entry mode" counts={stats.entryModeCounts} />
            <BarList title="By main language" counts={stats.mainLanguageCounts} />
            <BarList title="By area" counts={stats.areaCounts} />
            <BarList title="By collector" counts={stats.collectorCounts} />

            {/* 6. データ品質 */}
            <div className="card count-card">
              <h3>Data quality</h3>
              <div className="count-row">
                <span>Missing photos</span>
                <span className="n">{stats.missingPhotoCount}</span>
              </div>
              <div className="count-row">
                <span>Missing source photos</span>
                <span className="n">{stats.missingSourcePhotoCount}</span>
              </div>
              <div className="count-row">
                <span>Records without GPS</span>
                <span className="n">
                  {withGps == null ? '—' : stats.recordCount - withGps}
                </span>
              </div>
              <div className="count-row">
                <span>Records without photo</span>
                <span className="n">
                  {withPhoto == null ? '—' : stats.recordCount - withPhoto}
                </span>
              </div>
              <div className="count-row">
                <span>Records without source photo</span>
                <span className="n">
                  {withSource == null ? '—' : stats.recordCount - withSource}
                </span>
              </div>
              <div className="count-row">
                <span>Unknown EntryMode</span>
                <span className="n">{stats.entryModeCounts['unknown'] ?? 0}</span>
              </div>
              <div className="count-row">
                <span>Unknown DataStatus</span>
                <span className="n">{ds['unknown'] ?? 0}</span>
              </div>
            </div>
          </div>

          {/* 7. 快捷入口 */}
          <h3 className="detail-section" style={{ marginTop: 20 }}>Shortcuts</h3>
          <div className="shortcut-row">
            <Link className="btn" to="/database">Open Database</Link>
            <Link className="btn" to="/review">Open Review Queue</Link>
            <Link className="btn" to="/map">Open Map</Link>
            <Link className="btn" to="/export">Export Data</Link>
            <Link className="btn primary" to="/database">Import Dataset</Link>
          </div>
        </>
      )}
    </>
  );
}
