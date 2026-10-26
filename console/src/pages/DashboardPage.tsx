import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import {
  API_BASE_URL, ApiError, IS_DESKTOP, getRecords, getStatsSummary,
} from '../api/client';
import type { StatsSummary } from '../api/types';
import StatusBadge from '../components/database/StatusBadge';
import { enumLabel } from '../lib/enumLabels';
import { CANONICAL_BY_CODE, LANG_COLOR, MAIN_LANGS, langCode } from '../lib/langColors';
import { PENDING_STATUSES } from '../reviewStatus';

const DATA_STATUS_ORDER = ['reviewed', 'needs_review', 'verified', 'submitted', 'raw', 'ai_drafted', 'rejected'];

function Kpi({ label, value, to, accent }: {
  label: string; value: number | string; to?: string; accent?: boolean;
}) {
  const body = (
    <>
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{value}</div>
    </>
  );
  const cls = `kpi${accent ? ' accent' : ''}`;
  return to ? <Link className={cls} to={to}>{body}</Link> : <div className={cls}>{body}</div>;
}

/** 区块見出し＋「名称 … 数」の点線行。 */
function Rows({ title, rows }: {
  title: string;
  rows: { key: string; label: React.ReactNode; n: number; muted?: boolean }[];
}) {
  return (
    <div className="dash-block">
      <h3>{title}</h3>
      {rows.map((r) => (
        <div key={r.key} className={`dash-row${r.muted ? ' muted' : ''}`}>
          <span>{r.label}</span>
          <span className="mono">{r.n}</span>
        </div>
      ))}
    </div>
  );
}

export default function DashboardPage() {
  const { t } = useTranslation();
  const [stats, setStats] = useState<StatsSummary | null>(null);
  const [withGps, setWithGps] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getStatsSummary()
      .then(setStats)
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)));
    // GPS 件数は既存 /records の hasGps 筛选から導出（backend 変更なし）。
    getRecords({ hasGps: true, page: 1, pageSize: 1 })
      .then((r) => setWithGps(r.total)).catch(() => {});
  }, []);

  if (error) {
    return (
      <div className="error-box">
        <strong>{t('dashboard.statsError')}</strong>
        <div className="hint">
          {error}
          <br />
          {/* 桌面版は backend を shell が自動起動する — uvicorn の案内は Web/開発モードのみ。 */}
          {!IS_DESKTOP && (
            <>
              {t('dashboard.startBackendHint')}{' '}
              <code>cd backend && uvicorn app.main:app --port 8000</code>
              <br />
            </>
          )}
          {t('dashboard.currentUrl')}: <code>{API_BASE_URL}</code>
        </div>
      </div>
    );
  }
  if (!stats) return <div className="muted">{t('dashboard.loading')}</div>;

  const ds = stats.dataStatusCounts;
  const waiting = PENDING_STATUSES.reduce((a, k) => a + (ds[k] ?? 0), 0);

  // 主要語言: 主要 6 言語＋その他（不明・未記録・その他の言語をまとめる）。
  const langTotals: Record<string, number> = {};
  for (const [k, n] of Object.entries(stats.mainLanguageCounts)) {
    const code = langCode(k);
    langTotals[code] = (langTotals[code] ?? 0) + n;
  }
  const langRows = [...MAIN_LANGS, 'other' as const]
    .map((c) => ({ code: c, n: langTotals[c] ?? 0 }))
    .filter((r) => r.n > 0);
  const langSum = langRows.reduce((a, r) => a + r.n, 0) || 1;
  const langName = (c: string) =>
    c === 'other' ? t('dashboard.otherLanguages') : enumLabel(t, CANONICAL_BY_CODE[c]);

  const named = (k: string) =>
    k === 'unknown' ? t('dashboard.unrecorded')
      : k === 'legacy' ? t('dashboard.legacy') : k;
  const byCount = (o: Record<string, number>) => Object.entries(o).sort((a, b) => b[1] - a[1]);
  const missing = stats.missingPhotoCount + stats.missingSourcePhotoCount;

  return (
    <div className="dash">
      <section className="dash-hero">
        <div className="dash-head">
          <div className="dash-num">{stats.recordCount}</div>
          <h1 className="dash-title">{t('dashboard.headline')}</h1>
          <i className="dash-rule" />
        </div>
      </section>

      <div className="kpi-row">
        <Kpi label={t('dashboard.totalRecords')} value={stats.recordCount} to="/database" />
        <Kpi label={t('dashboard.withGps')} value={withGps ?? '—'} to="/map" />
        <Kpi label={t('dashboard.waitingReview')} value={waiting} to="/review" accent />
        <Kpi label={t('dashboard.reviewed')} value={ds.reviewed ?? 0} />
        <Kpi label={t('dashboard.verified')} value={ds.verified ?? 0} />
        <Kpi label={t('dashboard.sourcePhotos')} value={stats.sourcePhotoCount} />
      </div>

      <div className="dash-cols">
        <div className="dash-block">
          <h3>{t('dashboard.byMainLanguage')}</h3>
          <div className="stack-bar">
            {langRows.map((r) => (
              <span key={r.code} style={{ flex: r.n, background: LANG_COLOR[r.code] }} />
            ))}
          </div>
          {langRows.map((r) => (
            <div key={r.code} className="dash-row">
              <span>
                <i className="sw" style={{ background: LANG_COLOR[r.code] }} />
                {langName(r.code)}
                <em className="mono">{((r.n / langSum) * 100).toFixed(1)}%</em>
              </span>
              <span className="mono">{r.n}</span>
            </div>
          ))}
        </div>

        <div>
          <Rows
            title={t('dashboard.byDataStatus')}
            rows={DATA_STATUS_ORDER.filter((k) => ds[k]).map((k) => ({
              key: k, label: <StatusBadge value={k} />, n: ds[k],
            }))}
          />
          <Rows
            title={t('dashboard.byEntryMode')}
            rows={byCount(stats.entryModeCounts).map(([k, n]) => ({
              key: k,
              label: k === 'unknown' ? t('dashboard.unrecorded') : t(`status.${k}`, { defaultValue: k }),
              n,
              muted: k === 'unknown',
            }))}
          />
        </div>

        <div>
          <Rows
            title={t('dashboard.byCollector')}
            rows={byCount(stats.collectorCounts).map(([k, n]) => ({
              key: k, label: named(k), n, muted: k === 'unknown',
            }))}
          />
          <div className={`dash-flag${missing ? ' warn' : ''}`}>
            <i />
            {t('dashboard.missingFiles', { n: missing })}
          </div>
        </div>
      </div>
    </div>
  );
}
