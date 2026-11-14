import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router-dom';
import {
  API_BASE_URL, ApiError, IS_DESKTOP, getRecords, getStatsSummary,
} from '../api/client';
import type { StatsSummary } from '../api/types';
import { useCanvasSlot } from '../components/explore/ExploreContext';
import useSharedFilters from '../hooks/useSharedFilters';
import { enumLabel } from '../lib/enumLabels';
import { CANONICAL_BY_CODE, LANG_COLOR, MAIN_LANGS, langCode } from '../lib/langColors';
import { PENDING_STATUSES } from '../reviewStatus';

export default function DashboardPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const shared = useSharedFilters();
  const slotRef = useCanvasSlot('themes');
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

  const done = (ds.reviewed ?? 0) + (ds.verified ?? 0);
  const total = stats.recordCount || 1;
  const progress = [
    { key: 'verified', n: ds.verified ?? 0, cls: 'p-verified' },
    { key: 'reviewed', n: ds.reviewed ?? 0, cls: 'p-reviewed' },
    { key: 'waiting', n: waiting, cls: 'p-waiting' },
    { key: 'rejected', n: ds.rejected ?? 0, cls: 'p-rejected' },
  ].filter((x) => x.n > 0);
  const members = byCount(stats.collectorCounts);
  const memberMax = Math.max(1, ...members.map(([, n]) => n));
  const openMember = (id: string) => {
    if (id === 'unknown' || id === 'legacy') return;
    shared.replace({ collectorId: id });
    navigate('/database');
  };

  return (
    <div className="ov">
      {/* 上: いまの状態と次の一手（home） */}
      <section className="ov-hero">
        <img className="ov-logo" src="logo.png" alt="" />
        <div className="ov-hero-t">
          <h1><b>{stats.recordCount}</b> {t('dashboard.headline')}</h1>
        </div>
        <div className="ov-hero-actions">
          <Link className="btn" to="/database">{t('dashboard.openDatabase')}</Link>
          <Link className="btn primary" to="/review">{t('dashboard.continueReview')}</Link>
        </div>
      </section>

      <section className="ov-card ov-progress">
        <div className="ov-card-h">
          <span />
          <span className="mono muted">{t('dashboard.progressDone', { done, total: stats.recordCount, pct: Math.round((done / total) * 100) })}</span>
        </div>
        <div className="ov-bar">
          {progress.map((x) => <span key={x.key} className={x.cls} style={{ flex: x.n }} title={`${t(`dashboard.p.${x.key}`)} ${x.n}`} />)}
        </div>
        <div className="ov-legend">
          {progress.map((x) => (
            <span key={x.key}><i className={x.cls} />{t(`dashboard.p.${x.key}`)}<b className="mono">{x.n}</b></span>
          ))}
        </div>
        <div className="ov-facts">
          <Link to="/database?view=map"><b>{withGps ?? '—'}</b>{t('dashboard.withGps')}</Link>
          <div><b>{stats.photoCount}</b>{t('dashboard.photos')}</div>
          <div><b>{stats.sourcePhotoCount}</b>{t('dashboard.sourcePhotos')}</div>
          <div className={missing ? 'warn' : ''}><b>{missing}</b>{t('dashboard.missingShort')}</div>
        </div>
      </section>

      {/* 主题: 一組の資料への入口（開くと資料庫の範囲になる）。下に関係画布への入口。 */}
      <section className="ov-themes">
        <div className="canvas-slot themes-slot" ref={slotRef} />
        <button type="button" className="more-card" onClick={() => navigate('/canvas')}>
          <span className="more-card-t">
            <b>{t('themes.moreTitle')} · {t('canvasPage.title')}</b>
          </span>
          <span className="more-card-go" aria-hidden="true">→</span>
        </button>
      </section>

      <div className="ov-cols">
        {/* 下左: 資料の構成 */}
        <section className="ov-card">
          <div className="ov-card-h"><h2>{t('dashboard.byMainLanguage')}</h2></div>
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
          <div className="ov-sub">
            <h3>{t('dashboard.byEntryMode')}</h3>
            <div className="ov-pills">
              {byCount(stats.entryModeCounts).map(([k, n]) => (
                <span key={k}>{k === 'unknown' ? t('dashboard.unrecorded') : t(`status.${k}`, { defaultValue: k })}<b className="mono">{n}</b></span>
              ))}
            </div>
          </div>
        </section>

        {/* 下右: チーム（採集者ごとの件数。クリックでその人の資料へ） */}
        <section className="ov-card">
          <div className="ov-card-h">
            <h2>{t('dashboard.team')}</h2>
            <span className="mono muted">{t('dashboard.teamCount', { n: members.length })}</span>
          </div>
          <div className="ov-team">
            {members.map(([k, n]) => (
              <button key={k} type="button" className="ov-member" onClick={() => openMember(k)}
                disabled={k === 'unknown' || k === 'legacy'} title={t('dashboard.openMember')}>
                <span className="ov-avatar">{named(k).slice(0, 2).toUpperCase()}</span>
                <span className="ov-member-t">
                  <span className="ov-member-n">{named(k)}</span>
                  <span className="ov-member-bar"><i style={{ width: `${(n / memberMax) * 100}%` }} /></span>
                </span>
                <span className="ov-member-c mono">{n}<em>{((n / total) * 100).toFixed(0)}%</em></span>
              </button>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
