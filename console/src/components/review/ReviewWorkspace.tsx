import { useEffect, useMemo, useRef, useState } from 'react';
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

  // 快捷键: 1 已审核→下一条 / 2 已确认 / 3 需复核 / X 拒绝 / Ctrl+S 保存。
  // 入力中（input・textarea・select）は Ctrl+S 以外を無視する。
  const keyHandler = useRef<((e: KeyboardEvent) => void) | null>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => keyHandler.current?.(e);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

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

  keyHandler.current = null; // 読込中・エラー中は旧記録へ誤操作しない
  if (error) {
    return (
      <div className="rv-viewer">
        <div className="error-box">
          <strong>{t('record.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      </div>
    );
  }
  if (!detail) return <div className="rv-viewer muted">{t('record.loading')}</div>;


  // 存在しない側を選んでいたら自動で他方へ（写真が片方しか無い記録がある）。
  const effView: 'crop' | 'source' =
    view === 'crop'
      ? (detail.photoUrl ? 'crop' : 'source')
      : (detail.sourcePhotoUrl ? 'source' : 'crop');
  const mainUrl = photoUrl(
    effView === 'crop' ? detail.photoUrl : detail.sourcePhotoUrl);

  const run = (a: ReviewActionDef) =>
    patch(actionPayload(a, detail?.data['_status'] ?? ''), a.key, a.leavesQueue);
  const act = (key: string) => REVIEW_ACTIONS.find((a) => a.key === key)!;
  const actionBtn = (key: string, cls: string, hint: string, label?: string) => (
    <button key={key} className={`btn ${cls}`} disabled={busy != null} onClick={() => run(act(key))}>
      {busy === key ? t('review.working') : label ?? t(act(key).labelKey)}
      <kbd>{hint}</kbd>
    </button>
  );

  keyHandler.current = (e) => {
    if (busy != null || lightbox) return;
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
      e.preventDefault();
      if (dirty) void patch({}, 'save', false);
      return;
    }
    const el = e.target as HTMLElement | null;
    if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
    if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
    const key = ({ '1': 'reviewed', '2': 'verified', '3': 'needs_review', x: 'rejected' } as Record<string, string>)[e.key.toLowerCase()];
    if (key) { e.preventDefault(); void run(act(key)); }
  };

  return (
    <>
      <div className="rv-viewer">
        <div className="rv-id">{detail.DisplayID || detail.SignID}</div>
        <div
          className="rv-photo"
          style={{ cursor: mainUrl ? 'zoom-in' : 'default' }}
          onClick={() => mainUrl && setLightbox(effView)}
        >
          {mainUrl
            ? <img src={mainUrl} alt={effView} />
            : <div className="muted">{t('review.noPhoto')}</div>}
          <span className="crop c1" /><span className="crop c2" />
          <span className="crop c3" /><span className="crop c4" />
        </div>
        <div className="rv-photo-bar">
          <div className="seg">
            <button type="button" className={effView === 'crop' ? 'on' : ''}
              disabled={!detail.photoUrl} onClick={() => setView('crop')}>
              {t('record.crop')}
            </button>
            <button type="button" className={effView === 'source' ? 'on' : ''}
              disabled={!detail.sourcePhotoUrl} onClick={() => setView('source')}>
              {t('record.source')}
            </button>
          </div>
          <span className="spacer" />
          <StatusBadge value={detail.data.DataStatus || detail.DataStatus} />
        </div>
        <details className="rv-meta">
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

      <div className="rv-fields">
        <div className="rv-fields-scroll">
          {/* v6 定義表と同じ区分・順序（schema から派生）。状態はアクションボタン経由でのみ変更する。 */}
          {groupedResearchFields(schema).map((g) => (
            <div key={g.key} className="rv-group">
              <h3>{t(`fields.group.${g.key}`)}</h3>
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

        <div className="rv-actions">
          {actionError && (
            <div className="error-box">
              <strong>{t('review.actionFailed')}</strong>
              <div className="hint">{actionError}</div>
            </div>
          )}
          {actionBtn('reviewed', 'primary wide', '1', t('review.actions.reviewedNext'))}
          <div className="rv-actions-row">
            {actionBtn('verified', '', '2')}
            {actionBtn('needs_review', 'accent', '3')}
            {actionBtn('rejected', 'danger', 'X')}
            <span className="spacer" />
            <button className="btn ghost" disabled={!dirty || busy != null}
              onClick={() => patch({}, 'save', false)}>
              {busy === 'save' ? t('record.saving') : t('record.save')}
              {dirty && <span className="dirty-dot" aria-label={t('record.unsaved')} />}
            </button>
            <button className="btn ghost" disabled={busy != null}
              onClick={() => navigate(`/database?record=${detail.id}`)}>
              {t('review.openInDatabase')}
            </button>
          </div>
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
    </>
  );
}
