import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useLocation } from 'react-router-dom';
import { API_BASE_URL, getHealth } from '../api/client';

const TITLE_KEYS: Record<string, string> = {
  '/': 'nav.dashboard',
  '/database': 'nav.database',
  '/map': 'nav.map',
  '/review': 'nav.review',
  '/ai': 'nav.ai',
  '/export': 'nav.export',
  '/settings': 'nav.settings',
};

/** 顶部栏: 現在ページ名＋backend 接続状態チップ。 */
export default function Topbar() {
  const { t } = useTranslation();
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
      ? t('topbar.online', { version, url: API_BASE_URL })
      : status === 'down'
        ? t('topbar.offline', { url: API_BASE_URL })
        : t('topbar.checking');

  const titleKey = TITLE_KEYS[pathname];
  return (
    <header className="topbar">
      <span className="page-title">{titleKey ? t(titleKey) : 'LLMap'}</span>
      <span className="spacer" />
      <span className={chipClass}>
        <span className="dot" />
        {chipText}
      </span>
    </header>
  );
}
