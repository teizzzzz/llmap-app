import { NavLink } from 'react-router-dom';

const NAV = [
  { to: '/', label: 'Dashboard', icon: '▦', end: true },
  { to: '/database', label: 'Database', icon: '☰' },
  { to: '/map', label: 'Map', icon: '◎' },
  { to: '/review', label: 'Review', icon: '✓' },
  { to: '/ai', label: 'AI Processing', icon: '✦' },
  { to: '/export', label: 'Export', icon: '⇩' },
  { to: '/settings', label: 'Settings', icon: '⚙' },
];

export default function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="title">LLMap</div>
        <div className="subtitle">Research Console</div>
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
            {item.label}
          </NavLink>
        ))}
      </nav>
      <div className="sidebar-footer">console v0.5.0 · local-first</div>
    </aside>
  );
}
