import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { NavLink, useLocation } from 'react-router-dom';
import pkg from '../../package.json';
import { API_BASE_URL, getHealth } from '../api/client';
import useAiEnabled from '../hooks/useAiEnabled';

// 研究の流れに沿った並び（導入 → 審核 → 地図で確認 → 導出、AI は任意、概覧は参照用）。
// labelKey は i18n キー。ルートパスは内部値なので翻訳しない。
const NAV = [
  { to: '/database', labelKey: 'nav.database' },
  { to: '/review', labelKey: 'nav.review' },
  { to: '/map', labelKey: 'nav.map' },
  { to: '/export', labelKey: 'nav.export' },
  { to: '/ai', labelKey: 'nav.ai' },
  { to: '/overview', labelKey: 'nav.overview' },
];

export default function Sidebar() {
  const { t } = useTranslation();
  const { pathname } = useLocation();
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
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">LLMAP</div>
      <nav>
        {/* AI は任意: 設定で切っていれば入口を出さない。 */}
        {NAV.filter((n) => aiOn || n.to !== '/ai').map((n) => (
          <NavLink key={n.to} to={n.to} className={item}>
            {t(n.labelKey)}
          </NavLink>
        ))}
      </nav>
      {/* 設定は侧栏の底に固定（研究の流れとは別の常設項目）。 */}
      <div className="sidebar-bottom">
        <NavLink to="/settings" className={item}>
          {t('nav.settings')}
        </NavLink>
        <div className={`sidebar-footer ${status}`} title={detail}>
          <span className="dot" />
          {t(`topbar.${status === 'ok' ? 'connected' : status === 'down' ? 'disconnected' : 'checking'}`)}
        </div>
      </div>
    </aside>
  );
}
