import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { NavLink, useLocation } from 'react-router-dom';
import pkg from '../../package.json';
import { API_BASE_URL, getHealth } from '../api/client';

// labelKey は i18n キー。ルートパスは内部値なので翻訳しない。
const NAV = [
  { to: '/', labelKey: 'nav.dashboard', end: true },
  { to: '/database', labelKey: 'nav.database' },
  { to: '/map', labelKey: 'nav.map' },
  { to: '/review', labelKey: 'nav.review' },
  { to: '/ai', labelKey: 'nav.ai' },
  { to: '/export', labelKey: 'nav.export' },
  { to: '/settings', labelKey: 'nav.settings' },
];

export default function Sidebar() {
  const { t } = useTranslation();
  const { pathname } = useLocation();
  const [status, setStatus] = useState<'checking' | 'ok' | 'down'>('checking');
  const [version, setVersion] = useState('');

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
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">LLMAP</div>
      <nav>
        {NAV.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
          >
            {t(item.labelKey)}
          </NavLink>
        ))}
      </nav>
      <div className={`sidebar-footer ${status}`} title={detail}>
        <span className="dot" />
        {t(`topbar.${status === 'ok' ? 'connected' : status === 'down' ? 'disconnected' : 'checking'}`)}
      </div>
    </aside>
  );
}
