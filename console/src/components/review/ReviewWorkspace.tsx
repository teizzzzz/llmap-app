import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { ApiError, getRecord, photoUrl, updateRecord } from '../../api/client';
import type { RecordDetail, SchemaInfo } from '../../api/types';
import {
  actionPayload,
  REVIEW_ACTIONS,
  type ReviewActionDef,
} from '../../reviewStatus';
import FieldEditor from '../database/FieldEditor';
import PhotoThumb from '../database/PhotoThumb';
import StatusBadge from '../database/StatusBadge';

// 審核で編集を許可する研究字段（状態はアクションボタン経由でのみ変更する）。
const EDITABLE_FIELDS = [
  '主要言語', '補助言語', '文字体系', '担体類型', '設置主体', '多言語関係', '備考',
];

// 只読の元情報。
const META_FIELDS = [
  'SignID', 'CaptureID', 'DisplayID', 'EntryMode', 'DataStatus', '_status',
  '採集者ID', '地区コード', '採集日時', '緯度', '経度',
  '写真ファイル名', '元写真ファイル名', 'SchemaVersion', 'AppVersion',
  'CropRect', // 可視化 overlay は TODO（当面はテキスト表示）
];

/** 審核工作区: 写真 / 字段編集 / 元情報＋アクション の3列。 */
export default function ReviewWorkspace({
  recordId,
  schema,
  onDirtyChange,
  onActioned,
}: {
  recordId: number;
  schema: SchemaInfo | null;
  onDirtyChange: (dirty: boolean) => void;
  /** 保存/審核動作の成功後に呼ぶ（advance=true なら次の記録へ進む）。 */
  onActioned: (recordId: number, advance: boolean) => void;
}) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [detail, setDetail] = useState<RecordDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null); // 実行中のアクション key
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    setDetail(null);
    setError(null);
    setDraft({});
    setActionError(null);
    getRecord(recordId)
      .then(setDetail)
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)));
  }, [recordId]);

  const current = (f: string) => draft[f] ?? detail?.data[f] ?? '';
  const changed = useMemo(() => {
    if (!detail) return {};
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(draft)) {
      if (v !== (detail.data[k] ?? '')) out[k] = v;
    }
    return out;
  }, [draft, detail]);
  const dirty = Object.keys(changed).length > 0;
  useEffect(() => onDirtyChange(dirty), [dirty, onDirtyChange]);

  /** 字段変更（＋任意の状態 payload）を保存する。審核動作は変更も一緒に保存。 */
  const patch = async (
    extra: Record<string, string>,
    busyKey: string,
    advance: boolean,
  ) => {
    if (!detail) return;
    setBusy(busyKey);
    setActionError(null);
    try {
      const updated = await updateRecord(detail.id, { ...changed, ...extra });
      setDetail(updated);
      setDraft({});
      onActioned(detail.id, advance);
    } catch (e: unknown) {
      setActionError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  };

  if (error) {
    return (
      <div className="card review-workspace">
        <div className="error-box">
          <strong>{t('record.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      </div>
    );
  }
  if (!detail) return <div className="card review-workspace muted">{t('record.loading')}</div>;

  const openPhoto = (path: string | null) => {
    const url = photoUrl(path);
    if (url) window.open(url, '_blank', 'noopener');
  };

  const actionBtn = (a: ReviewActionDef) => (
    <button
      key={a.key}
      className={`btn review-action ${a.kind}`}
      disabled={busy != null}
      onClick={() =>
        patch(actionPayload(a, detail?.data['_status'] ?? ''), a.key, a.leavesQueue)}
    >
      {busy === a.key ? t('review.working') : t(a.labelKey)}
    </button>
  );

  return (
    <div className="card review-workspace">
      <div className="review-head">
        <div>
          <div className="detail-title">{detail.DisplayID || detail.SignID}</div>
          <div className="muted mono" style={{ fontSize: 11.5 }}>{detail.SignID}</div>
        </div>
        <div className="detail-badges">
          <StatusBadge value={current('EntryMode') || detail.EntryMode} />
          <StatusBadge value={detail.data.DataStatus || detail.DataStatus} />
        </div>
      </div>

      <div className="review-columns">
        {/* ── 写真 ── */}
        <div className="review-photos">
          <figure onClick={() => openPhoto(detail.photoUrl)} title={t('record.openFull')}>
            <PhotoThumb src={photoUrl(detail.photoUrl)} size={220} alt="crop" />
            <figcaption className="muted">
              {t('record.crop')} — {t('record.openFull')}
            </figcaption>
          </figure>
          <figure onClick={() => openPhoto(detail.sourcePhotoUrl)} title={t('record.openFull')}>
            <PhotoThumb src={photoUrl(detail.sourcePhotoUrl)} size={220} alt="source" />
            <figcaption className="muted">
              {t('record.source')} — {t('record.openFull')}
            </figcaption>
          </figure>
        </div>

        {/* ── 字段編集 ── */}
        <div className="review-fields">
          <h3 className="detail-section">
            {t('record.researchFields')}{' '}
            {dirty && <span className="dirty-flag">{t('record.unsaved')}</span>}
          </h3>
          <div className="edit-grid">
            {EDITABLE_FIELDS.map((f) => (
              <label key={f} className="edit-row">
                <span className="k">{t(`fields.${f}`, { defaultValue: f })}</span>
                <FieldEditor
                  field={f}
                  value={current(f)}
                  schema={schema}
                  onChange={(v) => setDraft((d) => ({ ...d, [f]: v }))}
                />
              </label>
            ))}
          </div>
        </div>

        {/* ── 元情報＋アクション ── */}
        <div className="review-meta">
          <h3 className="detail-section">{t('record.metadata')}</h3>
          <div className="identity-grid">
            {META_FIELDS.map((f) => (
              <div key={f} className="identity-row">
                <span className="k">{t(`fields.${f}`, { defaultValue: f })}</span>
                <span className="v mono">{detail.data[f] || '—'}</span>
              </div>
            ))}
          </div>

          <h3 className="detail-section">{t('review.actionsTitle')}</h3>
          {actionError && (
            <div className="error-box" style={{ marginBottom: 8 }}>
              <strong>{t('review.actionFailed')}</strong>
              <div className="hint">{actionError}</div>
            </div>
          )}
          <div className="review-actions">
            <button
              className="btn"
              disabled={!dirty || busy != null}
              onClick={() => patch({}, 'save', false)}
            >
              {busy === 'save' ? t('record.saving') : t('review.saveChanges')}
            </button>
            {REVIEW_ACTIONS.map(actionBtn)}
            <button
              className="btn"
              disabled={busy != null}
              onClick={() => navigate(`/database?record=${detail.id}`)}
            >
              {t('common.openInDatabase')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
