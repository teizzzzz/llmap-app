import { useTranslation } from 'react-i18next';
import { API_BASE_URL } from '../api/client';
import { SUPPORTED_LANGUAGES, setLanguage } from '../i18n';

export default function SettingsPage() {
  const { t, i18n } = useTranslation();
  return (
    <>
      <div className="page-header">
        <h1>{t('settings.title')}</h1>
        <p>{t('settings.subtitle')}</p>
      </div>

      {/* 言語切替: 即時反映・localStorage 保存（Web / Desktop 共通）。 */}
      <div className="card" style={{ marginBottom: 14 }}>
        <h3 style={{ marginTop: 0 }}>{t('settings.language')}</h3>
        <div className="review-tabs" style={{ marginBottom: 10 }}>
          {SUPPORTED_LANGUAGES.map((l) => (
            <button
              key={l.code}
              className={`chip${i18n.language === l.code ? ' on' : ''}`}
              onClick={() => setLanguage(l.code)}
            >
              {l.label}
            </button>
          ))}
        </div>
        <p className="muted" style={{ margin: '0 0 4px' }}>{t('settings.languageDesc')}</p>
        <p className="muted" style={{ margin: 0 }}>{t('settings.languageNote')}</p>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>{t('settings.backendUrl')}</h3>
        <p>
          {t('settings.current')}: <code>{API_BASE_URL}</code>
        </p>
        <p className="muted">
          {t('settings.backendHelpPrefix')} <code>console/.env</code> ·{' '}
          <code>VITE_API_BASE_URL=http://host:port</code> {t('settings.backendHelpSuffix')}
        </p>
      </div>
    </>
  );
}
