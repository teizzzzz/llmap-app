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
import { groupedResearchFields } from '../../lib/researchFields';
import PhotoLightbox from '../PhotoLightbox';
import FieldEditor from '../database/FieldEditor';
import PhotoThumb from '../database/PhotoThumb';
import StatusBadge from '../database/StatusBadge';

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
  const [lightbox, setLightbox] = useState<'crop' | 'source' | null>(null);
  // 大画面ビューアの表示対象（裁切図/元写真）。記録が変わったら裁切図に戻す。
  const [view, setView] = useState<'crop' | 'source'>('crop');
  useEffect(() => setView('crop'), [recordId]);

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

  // 字段変更。文字性を「記号/対象外」へ変えたら B 言語 3 字段を「—」に連動
  // （v6: 文字が無ければ言語も無い）。「文字」へ戻しても自動復元はしない。
  const applyField = (f: string, v: string) =>
    setDraft((d) => {
      const next = { ...d, [f]: v };
      if (f === '文字性' && (v === '記号' || v === '対象外')) {
        next['主要言語'] = '—';
        next['補助言語'] = '—';
        next['装飾の言語'] = '—';
      }
      return next;
    });
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


  // 存在しない側を選んでいたら自動で他方へ（写真が片方しか無い記録がある）。
  const effView: 'crop' | 'source' =
    view === 'crop'
      ? (detail.photoUrl ? 'crop' : 'source')
      : (detail.sourcePhotoUrl ? 'source' : 'crop');
  const mainUrl = photoUrl(
    effView === 'crop' ? detail.photoUrl : detail.sourcePhotoUrl);

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

      <div className="review-columns review-columns--viewer">
        {/* ── 字段編集（画面右。row-reverse で視覚順はビューアが左）── */}
        <div className="review-fields">
          {/* 保存・審核アクションは字段列の最上部に sticky で常時表示
              （ユーザー要望: ボタンは右側へ。スクロールしても消えない）。 */}
          <div className="review-actionbar">
            {actionError && (
              <div className="error-box" style={{ marginBottom: 6 }}>
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

          <h3 className="detail-section">
            {t('record.researchFields')}{' '}
            {dirty && <span className="dirty-flag">{t('record.unsaved')}</span>}
          </h3>
          {/* v6 定義表と同じ区分・順序（schema から派生）。
              状態はアクションボタン経由でのみ変更する。 */}
          {groupedResearchFields(schema).map((g) => (
            <div key={g.key}>
              <div className="muted" style={{ margin: '8px 0 4px', fontSize: 12, fontWeight: 600 }}>
                {t(`fields.group.${g.key}`)}
              </div>
              <div className="edit-grid">
                {g.fields.map((f) => (
                  <label key={f} className="edit-row">
                    <span className="k">{t(`fields.${f}`, { defaultValue: f })}</span>
                    <FieldEditor
                      field={f}
                      value={current(f)}
                      schema={schema}
                      textType={current('文字性')}
                      onChange={(v) => applyField(f, v)}
                    />
                  </label>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* ── 大画面ビューア（画面左・sticky）＋アクション ──
            標注効率のため詳細画面で写真を大きく出し、原寸表示を開く回数を減らす。
            下の縮略バーで裁切図/元写真を切替。元情報は既定で折りたたみ。 */}
        <div className="review-viewer">
          <div
            className="review-viewer-main"
            style={{ cursor: mainUrl ? 'zoom-in' : 'default' }}
            title={t('record.openFull')}
            onClick={() => mainUrl && setLightbox(effView)}
          >
            {mainUrl
              ? <img src={mainUrl} alt={effView} />
              : <div className="muted">{t('review.noPhoto')}</div>}
          </div>
          <div className="review-viewer-thumbs">
            <button
              type="button"
              className={`viewer-thumb${effView === 'crop' ? ' on' : ''}`}
              disabled={!detail.photoUrl}
              onClick={() => setView('crop')}
            >
              <PhotoThumb src={photoUrl(detail.photoUrl)} size={56} alt="crop" />
              <span>{t('record.crop')}</span>
            </button>
            <button
              type="button"
              className={`viewer-thumb${effView === 'source' ? ' on' : ''}`}
              disabled={!detail.sourcePhotoUrl}
              onClick={() => setView('source')}
            >
              <PhotoThumb src={photoUrl(detail.sourcePhotoUrl)} size={56} alt="source" />
              <span>{t('record.source')}</span>
            </button>
            <span className="spacer" />
            <span className="muted" style={{ fontSize: 11.5, alignSelf: 'center' }}>
              {t('record.openFull')}
            </span>
          </div>

          <details className="review-meta-details">
            <summary>{t('record.metadata')}</summary>
            <div className="identity-grid">
              {META_FIELDS.map((f) => (
                <div key={f} className="identity-row">
                  <span className="k">{t(`fields.${f}`, { defaultValue: f })}</span>
                  <span className="v mono">{detail.data[f] || '—'}</span>
                </div>
              ))}
            </div>
          </details>
        </div>
      </div>

      {lightbox && (
        <PhotoLightbox
          items={[{
            title: detail.DisplayID || detail.SignID,
            cropUrl: photoUrl(detail.photoUrl),
            sourceUrl: photoUrl(detail.sourcePhotoUrl),
          }]}
          index={0}
          initialView={lightbox}
          onClose={() => setLightbox(null)}
        />
      )}
    </div>
  );
}
