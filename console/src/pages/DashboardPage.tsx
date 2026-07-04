import { useEffect, useState } from 'react';
import { API_BASE_URL, ApiError, getStatsSummary } from '../api/client';
import type { StatsSummary } from '../api/types';

function CountCard({ title, counts }: { title: string; counts: Record<string, number> }) {
  const entries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  return (
    <div className="card count-card">
      <h3>{title}</h3>
      {entries.length === 0 ? (
        <div className="muted">No data yet.</div>
      ) : (
        entries.map(([k, v]) => (
          <div key={k} className="count-row">
            <span>{k}</span>
            <span className="n">{v}</span>
          </div>
        ))
      )}
    </div>
  );
}

export default function DashboardPage() {
  const [stats, setStats] = useState<StatsSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getStatsSummary()
      .then(setStats)
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, []);

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
          <div className="stat-grid">
            <div className="card stat-tile">
              <div className="label">Records</div>
              <div className="value">{stats.recordCount}</div>
            </div>
            <div className="card stat-tile">
              <div className="label">Datasets</div>
              <div className="value">{stats.datasetCount}</div>
            </div>
            <div className="card stat-tile">
              <div className="label">Photos</div>
              <div className="value">{stats.photoCount}</div>
            </div>
            <div className="card stat-tile">
              <div className="label">Source photos</div>
              <div className="value">{stats.sourcePhotoCount}</div>
            </div>
            <div className="card stat-tile">
              <div className="label">Missing photos</div>
              <div className="value">{stats.missingPhotoCount}</div>
            </div>
          </div>
          <div className="count-grid">
            <CountCard title="By main language" counts={stats.mainLanguageCounts} />
            <CountCard title="By data status" counts={stats.dataStatusCounts} />
            <CountCard title="By entry mode" counts={stats.entryModeCounts} />
            <CountCard title="By area" counts={stats.areaCounts} />
            <CountCard title="By collector" counts={stats.collectorCounts} />
          </div>
        </>
      )}
    </>
  );
}
