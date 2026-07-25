import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  API_BASE_URL, ApiError, getAiStatus, getConfig, getStorageSummary,
  storageCleanup, updateConfig,
} from '../api/client';
import type { AiStatus, AppConfig, StorageSummary } from '../api/types';
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

  // バッチ AI（プロバイダ・モデル・API キー）。キーは書き込みのみ — GET はヒントだけ返す。
  const [providerInput, setProviderInput] = useState('claude');
  const [claudeModelInput, setClaudeModelInput] = useState('');
  const [geminiModelInput, setGeminiModelInput] = useState('');
  const [claudeKeyInput, setClaudeKeyInput] = useState('');
  const [geminiKeyInput, setGeminiKeyInput] = useState('');
  const [savingAi, setSavingAi] = useState(false);
  const [aiMsg, setAiMsg] = useState<string | null>(null);
  const [aiError, setAiError] = useState<string | null>(null);
  // モデル選択肢は backend が唯一の正（/ai/status の modelOptions）。
  const [aiStatus, setAiStatus] = useState<AiStatus | null>(null);

  useEffect(() => {
    getAiStatus().then(setAiStatus).catch(() => {});
  }, []);

  useEffect(() => {
    if (config) {
      setProviderInput(config.aiProvider ?? 'claude');
      setClaudeModelInput(config.claudeModel ?? '');
      setGeminiModelInput(config.geminiModel ?? '');
    }
  }, [config]);

  const applyAi = async (payload: Parameters<typeof updateConfig>[0]) => {
    setSavingAi(true);
    setAiMsg(null);
    setAiError(null);
    try {
      const c = await updateConfig(payload);
      setConfig(c);
      setClaudeKeyInput('');
      setGeminiKeyInput('');
      setAiMsg(t('settings.aiSaved'));
    } catch (e: unknown) {
      setAiError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setSavingAi(false);
    }
  };

  const saveAi = () => {
    const payload: Parameters<typeof updateConfig>[0] = {
      aiProvider: providerInput,
    };
    if (claudeModelInput) payload.claudeModel = claudeModelInput;
    if (geminiModelInput) payload.geminiModel = geminiModelInput;
    // 空欄のキー入力は「変更しない」（消したい時は専用の削除ボタン）。
    if (claudeKeyInput.trim()) payload.claudeApiKey = claudeKeyInput.trim();
    if (geminiKeyInput.trim()) payload.geminiApiKey = geminiKeyInput.trim();
    applyAi(payload);
  };

  /** モデルの表示ラベル: ID + 訳語ヒント（未知 ID は素通し）。 */
  const modelLabel = (id: string) => {
    const hint = t(`settings.modelHint.${id}`, { defaultValue: '' });
    return hint ? `${id} — ${hint}` : id;
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

      {/* バッチ AI: プロバイダと API キー。キーは settings.json（ローカル）に保存。 */}
      {config && (
        <div className="card" style={{ marginBottom: 14 }}>
          <h3 style={{ marginTop: 0 }}>{t('settings.aiTitle')}</h3>
          <p className="muted" style={{ margin: '0 0 10px' }}>
            {t('settings.aiDesc')}
          </p>
          <div style={{ display: 'grid', gap: 10, maxWidth: 640 }}>
            <label className="filter-field">
              <span>{t('settings.aiProvider')}</span>
              <select
                value={providerInput}
                onChange={(e) => setProviderInput(e.target.value)}
              >
                <option value="claude">Claude</option>
                <option value="gemini">Gemini</option>
              </select>
            </label>
            {([
              ['claude', t('settings.aiClaudeModel'), claudeModelInput, setClaudeModelInput],
              ['gemini', t('settings.aiGeminiModel'), geminiModelInput, setGeminiModelInput],
            ] as const).map(([k, label, value, setValue]) => {
              const options = aiStatus?.modelOptions?.[k]
                ?? (value ? [value] : []);
              return (
                <label className="filter-field" key={`model-${k}`}>
                  <span>{label}</span>
                  <select value={value} onChange={(e) => setValue(e.target.value)}>
                    {options.map((m) => (
                      <option key={m} value={m}>{modelLabel(m)}</option>
                    ))}
                  </select>
                </label>
              );
            })}
            {([
              ['claude', t('settings.aiClaudeKey'), claudeKeyInput, setClaudeKeyInput,
                config.claudeApiKeySet, config.claudeApiKeyHint,
                { claudeApiKey: null }],
              ['gemini', t('settings.aiGeminiKey'), geminiKeyInput, setGeminiKeyInput,
                config.geminiApiKeySet, config.geminiApiKeyHint,
                { geminiApiKey: null }],
            ] as const).map(([k, label, value, setValue, isSet, hint, clearPayload]) => (
              <div key={k} style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <span style={{ minWidth: 110 }}>{label}</span>
                <input
                  type="password"
                  value={value}
                  placeholder={isSet
                    ? t('settings.aiKeySet', { hint })
                    : t('settings.aiKeyUnset')}
                  onChange={(e) => setValue(e.target.value)}
                  style={{ flex: 1 }}
                  autoComplete="off"
                />
                <button
                  className="btn"
                  disabled={savingAi || !isSet}
                  onClick={() => applyAi(clearPayload)}
                >
                  {t('settings.aiKeyClear')}
                </button>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginTop: 12 }}>
            <button className="btn primary" disabled={savingAi} onClick={saveAi}>
              {t('settings.exportDirSave')}
            </button>
            <span className="muted" style={{ fontSize: 12.5 }}>
              {t('settings.aiKeyNote')}
            </span>
          </div>
          {aiMsg && <div className="ok-box" style={{ marginTop: 10 }}>{aiMsg}</div>}
          {aiError && (
            <div className="error-box" style={{ marginTop: 10 }}>
              <div className="hint">{aiError}</div>
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
