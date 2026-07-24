import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  API_BASE_URL, ApiError, getConfig, getStorageSummary, storageCleanup,
  updateConfig,
} from '../api/client';
import type { AppConfig, StorageSummary } from '../api/types';
import { SUPPORTED_LANGUAGES, setLanguage } from '../i18n';

/** バイト数の人間向け表示（GB/MB/KB）。 */
const fmtBytes = (n: number): string => {
  if (n >= 1024 ** 3) return `${(n / 1024 ** 3).toFixed(2)} GB`;
  if (n >= 1024 ** 2) return `${(n / 1024 ** 2).toFixed(1)} MB`;
  return `${Math.ceil(n / 1024)} KB`;
};

export default function SettingsPage() {
  const { t, i18n } = useTranslation();
  const [storage, setStorage] = useState<StorageSummary | null>(null);
  const [storageError, setStorageError] = useState<string | null>(null);
  const [cleaning, setCleaning] = useState(false);
  const [cleanupMsg, setCleanupMsg] = useState<string | null>(null);

  // 導出目录設定（settings.json）。大きな zip を C 盘に置かないための設定。
  const [config, setConfig] = useState<AppConfig | null>(null);
  const [exportDirInput, setExportDirInput] = useState('');
  const [savingDir, setSavingDir] = useState(false);
  const [dirMsg, setDirMsg] = useState<string | null>(null);
  const [dirError, setDirError] = useState<string | null>(null);

  useEffect(() => {
    getConfig()
      .then((c) => {
        setConfig(c);
        setExportDirInput(c.exportDir ?? '');
      })
      .catch(() => {}); // 旧 backend（/config 未実装）でも設定页自体は動かす
  }, []);

  const applyExportDir = async (value: string | null) => {
    setSavingDir(true);
    setDirMsg(null);
    setDirError(null);
    try {
      const c = await updateConfig({ exportDir: value });
      setConfig(c);
      setExportDirInput(c.exportDir ?? '');
      setDirMsg(t('settings.exportDirSaved'));
    } catch (e: unknown) {
      setDirError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setSavingDir(false);
    }
  };

  const loadStorage = useCallback(() => {
    setStorageError(null);
    getStorageSummary()
      .then(setStorage)
      .catch((e: unknown) =>
        setStorageError(e instanceof ApiError ? e.message : String(e)));
  }, []);
  useEffect(loadStorage, [loadStorage]);

  /** 清掃: 確認 → 実削除 → 再集計。正式資産には backend 側でも触れない。 */
  const cleanup = async () => {
    if (!storage || storage.reclaimableBytes <= 0) return;
    const size = fmtBytes(storage.reclaimableBytes);
    if (!window.confirm(t('storage.cleanupConfirm', { size }))) return;
    setCleaning(true);
    setCleanupMsg(null);
    try {
      const r = await storageCleanup(false);
      if (r.ok) {
        setCleanupMsg(t('storage.cleanupDone', { size: fmtBytes(r.freedBytes ?? 0) }));
      } else {
        setCleanupMsg(t('storage.cleanupBlocked', { n: r.missingPhotoCount }));
      }
      loadStorage();
    } catch (e: unknown) {
      setCleanupMsg(e instanceof ApiError ? e.message : String(e));
    } finally {
      setCleaning(false);
    }
  };

  const cat = (label: string, bytes: number) => (
    <div className="count-row" key={label}>
      <span>{label}</span>
      <span className="n">{fmtBytes(bytes)}</span>
    </div>
  );

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

      {/* ストレージ（Step 15）: 使用量の可視化と旧導入遺留の清掃。 */}
      <div className="card" style={{ marginBottom: 14 }}>
        <h3 style={{ marginTop: 0 }}>{t('storage.title')}</h3>
        {storageError && (
          <div className="error-box"><div className="hint">{storageError}</div></div>
        )}
        {storage && (
          <>
            <p style={{ margin: '0 0 8px' }}>
              {t('storage.dataDir')}: <code>{storage.dataDir}</code>
            </p>
            <div style={{ maxWidth: 420 }}>
              {cat(t('storage.catPhotos'), storage.categories.photos)}
              {cat(t('storage.catSourcePhotos'), storage.categories.sourcePhotos)}
              {cat(t('storage.catDatabase'), storage.categories.database)}
              {storage.categories.archives > 0 &&
                cat(t('storage.catArchives'), storage.categories.archives)}
              {storage.categories.exports > 0 &&
                cat(t('storage.catExports'), storage.categories.exports)}
              {cat(t('storage.catImports'),
                storage.categories.imports + storage.categories.tmp)}
              {cat(t('storage.diskFree'), storage.diskFree)}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12 }}>
              <span className="muted">
                {t('storage.reclaimable')}:{' '}
                <b>{storage.reclaimableBytes > 0
                  ? fmtBytes(storage.reclaimableBytes)
                  : t('storage.nothingToClean')}</b>
              </span>
              <span className="spacer" />
              <button className="btn" onClick={loadStorage}>{t('common.refresh')}</button>
              <button
                className="btn primary"
                disabled={cleaning || storage.reclaimableBytes <= 0}
                onClick={cleanup}
              >
                {t('storage.cleanup')}
              </button>
            </div>
            {cleanupMsg && (
              <div className="ok-box" style={{ marginTop: 10 }}>{cleanupMsg}</div>
            )}
          </>
        )}
      </div>

      {/* 導出目录: 大きな zip を C 盘の data_dir ではなく任意の場所へ。 */}
      {config && (
        <div className="card" style={{ marginBottom: 14 }}>
          <h3 style={{ marginTop: 0 }}>{t('settings.exportDir')}</h3>
          <p className="muted" style={{ margin: '0 0 10px' }}>
            {t('settings.exportDirDesc')}
          </p>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', maxWidth: 640 }}>
            <input
              type="text"
              value={exportDirInput}
              placeholder={config.defaultExportDir}
              onChange={(e) => setExportDirInput(e.target.value)}
              style={{ flex: 1 }}
            />
            <button
              className="btn primary"
              disabled={savingDir}
              onClick={() => applyExportDir(exportDirInput.trim() || null)}
            >
              {t('settings.exportDirSave')}
            </button>
            <button
              className="btn"
              disabled={savingDir || config.exportDir === null}
              onClick={() => applyExportDir(null)}
            >
              {t('settings.exportDirReset')}
            </button>
          </div>
          <p className="muted" style={{ margin: '10px 0 0' }}>
            {t('settings.exportDirCurrent')}: <code>{config.effectiveExportDir}</code>
          </p>
          {dirMsg && <div className="ok-box" style={{ marginTop: 10 }}>{dirMsg}</div>}
          {dirError && (
            <div className="error-box" style={{ marginTop: 10 }}>
              <div className="hint">{dirError}</div>
            </div>
          )}
        </div>
      )}

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
