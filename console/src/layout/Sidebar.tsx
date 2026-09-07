import { useTranslation } from 'react-i18next';
import { NavLink } from 'react-router-dom';
import pkg from '../../package.json';

// labelKey は i18n キー。ルートパスは内部値なので翻訳しない。
const NAV = [
  { to: '/', labelKey: 'nav.dashboard', icon: '▦', end: true },
  { to: '/database', labelKey: 'nav.database', icon: '☰' },
  { to: '/map', labelKey: 'nav.map', icon: '◎' },
  { to: '/review', labelKey: 'nav.review', icon: '✓' },
  { to: '/ai', labelKey: 'nav.ai', icon: '✦' },
  { to: '/export', labelKey: 'nav.export', icon: '⇩' },
  { to: '/settings', labelKey: 'nav.settings', icon: '⚙' },
];

export default function Sidebar() {
  const { t } = useTranslation();
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="title">LLMap</div>
        <div className="subtitle">{t('app.subtitle')}</div>
      </div>
      <nav>
        {NAV.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
          >
            <span className="icon">{item.icon}</span>
            {t(item.labelKey)}
          </NavLink>
        ))}
      </nav>
      {/* 以前はここに硬编码で古い版号が残っていた — package.json を唯一の正とする */}
      <div className="sidebar-footer">console v{pkg.version} · local-first</div>
    </aside>
  );
}
