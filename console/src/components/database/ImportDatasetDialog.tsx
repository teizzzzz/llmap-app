import { useRef, useState } from 'react';
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
      setFileError(`"${f.name}" is not a .zip file. Please select a llmap_dataset_*.zip.`);
      return;
    }
    setFileError(null);
    setFile(f);
  };

  const upload = async () => {
    if (!file) {
      setFileError('Please select a Dataset Package (.zip) first.');
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
          <h2>Import Dataset Package</h2>
          <button className="btn" onClick={onClose}>✕</button>
        </div>

        {!result && (
          <>
            <p className="muted">
              Upload a package exported by LLMap Mobile
              (<code>llmap_dataset_YYYYMMDD_HHMMSS.zip</code>). Records go into the
              local database; photos are copied into backend storage. Duplicate
              SignIDs are skipped, never overwritten.
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
                Choose file…
              </button>
              {file ? (
                <span className="mono">
                  {file.name} <span className="muted">({fmtSize(file.size)})</span>
                </span>
              ) : (
                <span className="muted">No file selected.</span>
              )}
            </div>
            {fileError && (
              <div className="error-box" style={{ marginTop: 10 }}>{fileError}</div>
            )}
            {error && (
              <div className="error-box" style={{ marginTop: 10 }}>
                <strong>Import failed.</strong>
                <div className="hint">{error}</div>
              </div>
            )}
            <div className="detail-actions">
              <button
                className="btn primary"
                disabled={!file || uploading}
                onClick={upload}
              >
                {uploading ? 'Uploading…' : 'Upload'}
              </button>
              <button className="btn" onClick={onClose} disabled={uploading}>
                Cancel
              </button>
            </div>
          </>
        )}

        {result && (
          <>
            <div className="import-ok">✓ Dataset imported successfully</div>
            <div className="report-grid">
              <div className="report-row"><span>Dataset ID</span><b>{result.datasetId}</b></div>
              <div className="report-row"><span>Records in package</span><b>{result.recordCount}</b></div>
              <div className="report-row"><span>Imported</span><b>{result.importedRecordCount}</b></div>
              <div className="report-row"><span>Skipped</span><b>{result.skippedRecordCount}</b></div>
              <div className="report-row"><span>Photos</span><b>{result.photoCount}</b></div>
              <div className="report-row"><span>Source photos</span><b>{result.sourcePhotoCount}</b></div>
              <div className="report-row"><span>Missing photos</span><b>{result.missingPhotoCount}</b></div>
              <div className="report-row"><span>Missing source photos</span><b>{result.missingSourcePhotoCount}</b></div>
            </div>

            {result.duplicateSignIds.length > 0 && (
              <div className="warn-box">
                <strong>{result.duplicateSignIds.length} duplicate SignID(s) skipped</strong>
                <ul className="mono">
                  {result.duplicateSignIds.slice(0, 20).map((s) => <li key={s}>{s}</li>)}
                  {result.duplicateSignIds.length > 20 && (
                    <li>…and {result.duplicateSignIds.length - 20} more</li>
                  )}
                </ul>
              </div>
            )}

            {result.warnings.length > 0 && (
              <div className="warn-box">
                <strong>{result.warnings.length} warning(s)</strong>
                <ul>
                  {result.warnings.slice(0, 20).map((w, i) => <li key={i}>{w}</li>)}
                  {result.warnings.length > 20 && (
                    <li>…and {result.warnings.length - 20} more</li>
                  )}
                </ul>
              </div>
            )}

            <div className="detail-actions">
              <button className="btn primary" onClick={onClose}>View records</button>
              <button className="btn" onClick={() => { setResult(null); setFile(null); }}>
                Import another
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
