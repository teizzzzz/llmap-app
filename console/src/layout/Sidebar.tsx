import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import pkg from '../../package.json';
import { API_BASE_URL, getHealth } from '../api/client';
import useAiEnabled from '../hooks/useAiEnabled';
import { confirmLeave, hasUnsaved } from '../lib/unsavedGuard';

// 侧栏は 1 つの体系で固定（探索／研究の切替は廃止）。地図・照片云・色彩は資料庫の視図に入り、
// 探索の入口（主题・関係画布）は研究の流れと並べる。AI は任意（設定で隠せる）。
// labelKey は i18n キー。ルートパスは内部値なので翻訳しない。
const NAV = [
  { to: '/home', labelKey: 'nav.home' },
  { to: '/database', labelKey: 'nav.database' },
  { to: '/review', labelKey: 'nav.review' },
  { to: '/export', labelKey: 'nav.export' },
  { to: '/ai', labelKey: 'nav.ai' },
];

export default function Sidebar() {
  const { t } = useTranslation();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [status, setStatus] = useState<'checking' | 'ok' | 'down'>('checking');
  const [version, setVersion] = useState('');
  const [aiOn] = useAiEnabled();

  useEffect(() => {
    let cancelled = false;
    getHealth()
      .then((h) => {
        if (!cancelled) { setStatus('ok'); setVersion(h.version); }
      })
      .catch(() => { if (!cancelled) setStatus('down'); });
    return () => { cancelled = true; };
  }, [pathname]); // ページ切替のたびに軽く再確認

  // 版本・URL は画面に出さず tooltip にだけ残す（問い合わせ時に確認できるように）。
  const detail = `backend ${version || '—'} · ${API_BASE_URL} · console v${pkg.version}`;
  const item = ({ isActive }: { isActive: boolean }) => `nav-item${isActive ? ' active' : ''}`;
  // ページを離れる前に、ページ内の未保存（審核の字段欄）を確認する。
  const guarded = (to: string) => (e: React.MouseEvent) => {
    if (!hasUnsaved()) return;
    e.preventDefault();
    void confirmLeave('page').then((ok) => { if (ok) navigate(to); });
  };
  // 侧栏は畳める（写真・字段に場所を譲る）。状態は覚えておく。
  const [folded, setFolded] = useState(() => {
    try { return localStorage.getItem('llmap.sidebarFolded') === '1'; } catch { return false; }
  });
  useEffect(() => {
    document.body.classList.toggle('sidebar-folded', folded);
    try { localStorage.setItem('llmap.sidebarFolded', folded ? '1' : '0'); } catch { /* */ }
  }, [folded]);
  if (folded) {
    return (
      <button type="button" className="sidebar-unfold" onClick={() => setFolded(false)}
        title={t('nav.unfold')} aria-label={t('nav.unfold')}>☰</button>
    );
  }
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <span className="brand"><img src="logo.png" alt="" />LLMAP</span>
        <button type="button" className="sidebar-fold" onClick={() => setFolded(true)}
          title={t('nav.fold')} aria-label={t('nav.fold')}>«</button>
      </div>
      <nav>
        {/* AI は任意: 設定で切っていれば入口を出さない。 */}
        {NAV.filter((n) => aiOn || n.to !== '/ai').map((n) => (
          <NavLink key={n.to} to={n.to} className={item} onClick={guarded(n.to)}>
            {t(n.labelKey)}
          </NavLink>
        ))}
      </nav>
      {/* 設定は侧栏の底に固定（研究の流れとは別の常設項目）。 */}
      <div className="sidebar-bottom">
        <NavLink to="/settings" className={item} onClick={guarded('/settings')}>
          <svg className="nav-ico" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h0a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h0a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v0a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
          {t('nav.settings')}
        </NavLink>
{/* 接続できているときは何も出さない（切れたときだけ知らせる）。 */}
        {status === 'down' && (
                <div className={`sidebar-footer ${status}`} title={detail}>
          <span className="dot" />
          {t('topbar.disconnected')}
        </div>
        )}
      </div>
    </aside>
  );
}
