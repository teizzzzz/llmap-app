import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, importDatasetPackage } from '../../api/client';
import type { ImportDatasetResult } from '../../api/types';

const fmtSize = (n: number) =>
  n >= 1024 * 1024 ? `${(n / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(n / 1024)} KB`;

/** Dataset Package 導入ダイアログ（Step 15 で去重対応）。
    選択 → Upload → （重複包なら選択肢を提示）→ 導入レポート → 一覧刷新。 */
export default function ImportDatasetDialog({
  onClose,
  onImported,
}: {
  onClose: () => void;
  onImported: () => void; // 成功後に records / datasets を親が再取得する
}) {
  const { t } = useTranslation();
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [keepOriginal, setKeepOriginal] = useState(false);
  const [result, setResult] = useState<ImportDatasetResult | null>(null);

  const pick = (f: File | null) => {
    setError(null);
    setResult(null);
    if (f && !f.name.toLowerCase().endsWith('.zip')) {
      setFile(null);
      setFileError(t('import.notZip', { name: f.name }));
      return;
    }
    setFileError(null);
    setFile(f);
  };

  const upload = async (mode: 'ask' | 'fill_missing' = 'ask') => {
    if (!file) {
      setFileError(t('import.selectFirst'));
      return;
    }
    setUploading(true);
    setError(null);
    try {
      const report = await importDatasetPackage(file, { mode, keepOriginal });
      setResult(report);
      if (report.status !== 'duplicate') onImported();
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setUploading(false);
    }
  };

  const reset = () => {
    setResult(null);
    setFile(null);
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h2>{t('import.title')}</h2>
          <button className="btn" onClick={onClose}>✕</button>
        </div>

        {!result && (
          <>
            <p className="muted">
              {t('import.introUpload', { pattern: 'llmap_dataset_YYYYMMDD_HHMMSS.zip' })}{' '}
              {t('import.introDetail')}
            </p>
            <input
              ref={inputRef}
              type="file"
              accept=".zip,application/zip"
              style={{ display: 'none' }}
              onChange={(e) => pick(e.target.files?.[0] ?? null)}
            />
            <div className="file-row">
              <button className="btn" onClick={() => inputRef.current?.click()}>
                {t('import.chooseFile')}
              </button>
              {file ? (
                <span className="mono">
                  {file.name} <span className="muted">({fmtSize(file.size)})</span>
                </span>
              ) : (
                <span className="muted">{t('import.noFile')}</span>
              )}
            </div>
            <label className="muted" style={{
              display: 'flex', alignItems: 'center', gap: 6, marginTop: 10,
              fontSize: 12.5, cursor: 'pointer',
            }}>
              <input
                type="checkbox"
                checked={keepOriginal}
                onChange={(e) => setKeepOriginal(e.target.checked)}
              />
              {t('import.keepOriginal')}
            </label>
            {fileError && (
              <div className="error-box" style={{ marginTop: 10 }}>{fileError}</div>
            )}
            {error && (
              <div className="error-box" style={{ marginTop: 10 }}>
                <strong>{t('import.failed')}</strong>
                <div className="hint">{error}</div>
              </div>
            )}
            <div className="detail-actions">
              <button
                className="btn primary"
                disabled={!file || uploading}
                onClick={() => upload('ask')}
              >
                {uploading ? t('import.uploading') : t('import.upload')}
              </button>
              <button className="btn" onClick={onClose} disabled={uploading}>
                {t('common.cancel')}
              </button>
            </div>
          </>
        )}

        {/* 重複包: 整包 SHA-256 が既存 Dataset と一致（未導入のまま） */}
        {result?.status === 'duplicate' && (
          <>
            <div className="warn-box">
              <strong>{t('import.duplicateTitle')}</strong>
              <p style={{ margin: '6px 0 0' }}>
                {t('import.duplicateBody', {
                  name: result.existingDatasetName,
                  date: (result.existingImportedAt ?? '').slice(0, 10),
                })}
              </p>
            </div>
            <div className="detail-actions">
              <button className="btn primary" onClick={onClose}>
                {t('common.cancel')}
              </button>
              <button
                className="btn"
                disabled={uploading}
                onClick={() => upload('fill_missing')}
              >
                {uploading ? t('import.uploading') : t('import.duplicateFill')}
              </button>
            </div>
          </>
        )}

        {/* 欠落写真の補充完了 */}
        {result?.status === 'filled' && (
          <>
            <div className="import-ok">{t('import.filledOk')}</div>
            <div className="report-grid">
              <div className="report-row">
                <span>{t('import.restored')}</span><b>{result.restoredPhotoCount ?? 0}</b>
              </div>
              <div className="report-row">
                <span>{t('import.stillMissing')}</span><b>{result.stillMissingCount ?? 0}</b>
              </div>
            </div>
            <div className="detail-actions">
              <button className="btn primary" onClick={onClose}>{t('import.viewRecords')}</button>
              <button className="btn" onClick={reset}>{t('import.importAnother')}</button>
            </div>
          </>
        )}

        {result?.status === 'imported' && (
          <>
            <div className="import-ok">{t('import.success')}</div>
            <div className="report-grid">
              <div className="report-row"><span>{t('import.datasetId')}</span><b>{result.datasetId}</b></div>
              <div className="report-row"><span>{t('import.inPackage')}</span><b>{result.recordCount}</b></div>
              <div className="report-row"><span>{t('import.imported')}</span><b>{result.importedRecordCount}</b></div>
              <div className="report-row"><span>{t('import.skipped')}</span><b>{result.skippedRecordCount}</b></div>
              <div className="report-row"><span>{t('import.photos')}</span><b>{result.photoCount}</b></div>
              <div className="report-row"><span>{t('import.sourcePhotos')}</span><b>{result.sourcePhotoCount}</b></div>
              {(result.reusedPhotoCount ?? 0) > 0 && (
                <div className="report-row"><span>{t('import.reused')}</span><b>{result.reusedPhotoCount}</b></div>
              )}
              <div className="report-row"><span>{t('import.missingPhotos')}</span><b>{result.missingPhotoCount}</b></div>
              <div className="report-row"><span>{t('import.missingSourcePhotos')}</span><b>{result.missingSourcePhotoCount}</b></div>
            </div>

            {(result.duplicateSignIds?.length ?? 0) > 0 && (
              <div className="warn-box">
                <strong>{t('import.duplicates', { n: result.duplicateSignIds!.length })}</strong>
                <ul className="mono">
                  {result.duplicateSignIds!.slice(0, 20).map((s) => <li key={s}>{s}</li>)}
                  {result.duplicateSignIds!.length > 20 && (
                    <li>{t('import.andMore', { n: result.duplicateSignIds!.length - 20 })}</li>
                  )}
                </ul>
              </div>
            )}

            {(result.warnings?.length ?? 0) > 0 && (
              <div className="warn-box">
                <strong>{t('import.warnings', { n: result.warnings!.length })}</strong>
                <ul>
                  {result.warnings!.slice(0, 20).map((w, i) => <li key={i}>{w}</li>)}
                  {result.warnings!.length > 20 && (
                    <li>{t('import.andMore', { n: result.warnings!.length - 20 })}</li>
                  )}
                </ul>
              </div>
            )}

            <div className="detail-actions">
              <button className="btn primary" onClick={onClose}>{t('import.viewRecords')}</button>
              <button className="btn" onClick={reset}>{t('import.importAnother')}</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
