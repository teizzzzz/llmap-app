import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, importDatasetPackage } from '../../api/client';
import type { ImportDatasetResult } from '../../api/types';

const fmtSize = (n: number) =>
  n >= 1024 * 1024 ? `${(n / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(n / 1024)} KB`;

/** Dataset Package 導入ダイアログ。
    選択 → ファイル名/サイズ確認 → Upload → 導入レポート表示 → 一覧刷新。 */
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

  const upload = async () => {
    if (!file) {
      setFileError(t('import.selectFirst'));
      return;
    }
    setUploading(true);
    setError(null);
    try {
      const report = await importDatasetPackage(file);
      setResult(report);
      onImported(); // 表格・datasets・統計の元データを更新
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setUploading(false);
    }
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
                onClick={upload}
              >
                {uploading ? t('import.uploading') : t('import.upload')}
              </button>
              <button className="btn" onClick={onClose} disabled={uploading}>
                {t('common.cancel')}
              </button>
            </div>
          </>
        )}

        {result && (
          <>
            <div className="import-ok">{t('import.success')}</div>
            <div className="report-grid">
              <div className="report-row"><span>{t('import.datasetId')}</span><b>{result.datasetId}</b></div>
              <div className="report-row"><span>{t('import.inPackage')}</span><b>{result.recordCount}</b></div>
              <div className="report-row"><span>{t('import.imported')}</span><b>{result.importedRecordCount}</b></div>
              <div className="report-row"><span>{t('import.skipped')}</span><b>{result.skippedRecordCount}</b></div>
              <div className="report-row"><span>{t('import.photos')}</span><b>{result.photoCount}</b></div>
              <div className="report-row"><span>{t('import.sourcePhotos')}</span><b>{result.sourcePhotoCount}</b></div>
              <div className="report-row"><span>{t('import.missingPhotos')}</span><b>{result.missingPhotoCount}</b></div>
              <div className="report-row"><span>{t('import.missingSourcePhotos')}</span><b>{result.missingSourcePhotoCount}</b></div>
            </div>

            {result.duplicateSignIds.length > 0 && (
              <div className="warn-box">
                <strong>{t('import.duplicates', { n: result.duplicateSignIds.length })}</strong>
                <ul className="mono">
                  {result.duplicateSignIds.slice(0, 20).map((s) => <li key={s}>{s}</li>)}
                  {result.duplicateSignIds.length > 20 && (
                    <li>{t('import.andMore', { n: result.duplicateSignIds.length - 20 })}</li>
                  )}
                </ul>
              </div>
            )}

            {result.warnings.length > 0 && (
              <div className="warn-box">
                <strong>{t('import.warnings', { n: result.warnings.length })}</strong>
                <ul>
                  {result.warnings.slice(0, 20).map((w, i) => <li key={i}>{w}</li>)}
                  {result.warnings.length > 20 && (
                    <li>{t('import.andMore', { n: result.warnings.length - 20 })}</li>
                  )}
                </ul>
              </div>
            )}

            <div className="detail-actions">
              <button className="btn primary" onClick={onClose}>{t('import.viewRecords')}</button>
              <button className="btn" onClick={() => { setResult(null); setFile(null); }}>
                {t('import.importAnother')}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
