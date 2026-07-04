import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { API_BASE_URL, getHealth } from '../api/client';

const TITLES: Record<string, string> = {
  '/': 'Dashboard',
  '/database': 'Database',
  '/map': 'Map',
  '/review': 'Review',
  '/ai': 'AI Processing',
  '/export': 'Export',
  '/settings': 'Settings',
};

/** 顶部栏: 現在ページ名＋backend 接続状態チップ。 */
export default function Topbar() {
  const { pathname } = useLocation();
  const [status, setStatus] = useState<'checking' | 'ok' | 'down'>('checking');
  const [version, setVersion] = useState('');

  useEffect(() => {
    let cancelled = false;
    getHealth()
      .then((h) => {
        if (!cancelled) {
          setStatus('ok');
          setVersion(h.version);
        }
      })
      .catch(() => {
        if (!cancelled) setStatus('down');
      });
    return () => {
      cancelled = true;
    };
  }, [pathname]); // ページ切替のたびに軽く再確認

  const chipClass =
    status === 'ok' ? 'backend-chip ok' : status === 'down' ? 'backend-chip down' : 'backend-chip';
  const chipText =
    status === 'ok'
      ? `backend ${version} · ${API_BASE_URL}`
      : status === 'down'
        ? `backend offline · ${API_BASE_URL}`
        : 'checking backend…';

  return (
    <header className="topbar">
      <span className="page-title">{TITLES[pathname] ?? 'LLMap'}</span>
      <span className="spacer" />
      <span className={chipClass}>
        <span className="dot" />
        {chipText}
      </span>
    </header>
  );
}
