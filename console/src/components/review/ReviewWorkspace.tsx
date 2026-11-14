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
import { useEditorGuard } from '../../lib/unsavedGuard';
import useExplore from '../explore/ExploreContext';
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

export interface ReviewNav {
  position: number;
  total: number;
  canPrev: boolean;
  canNext: boolean;
  onPrev: () => void;
  onNext: () => void;
}

/** 審核工作区: 中＝写真（裁切図が既定・原図へ切替・クリックで拡大ビューア）、
    右＝研究字段（定義表の区分・順序）と、常に見える操作欄
    （前/次・保存・審核動作。快捷键は従来どおり）。元情報は写真の下に畳む。 */
export default function ReviewWorkspace({
  recordId,
  schema,
  onDirtyChange,
  onActioned,
  nav,
}: {
  recordId: number;
  schema: SchemaInfo | null;
  onDirtyChange: (dirty: boolean) => void;
  /** 保存/審核動作の成功後に呼ぶ（advance=true なら次の記録へ進む）。 */
  onActioned: (recordId: number, advance: boolean) => void;
  nav: ReviewNav;
}) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const ex = useExplore();
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

  // 前の記録の応答が後から届いても使わない（素早く J/K で進めたとき）。
  useEffect(() => {
    let stale = false;
    setDetail(null);
    setError(null);
    setDraft({});
    setActionError(null);
    getRecord(recordId)
      .then((d) => { if (!stale && d.id === recordId) setDetail(d); })
      .catch((e: unknown) => {
        if (!stale) setError(e instanceof ApiError ? e.message : String(e));
      });
    return () => { stale = true; };
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

  // 字段の記入状況（人の審核状態とは別に示す）。「—」は「該当なし」として記入済み扱い。
  const fieldGroups = useMemo(() => groupedResearchFields(schema), [schema]);
  const allFields = fieldGroups.flatMap((g) => g.fields);
  const filledCount = allFields.filter((f) => current(f).trim() !== '').length;

  /** 字段変更（＋任意の状態 payload）を保存する。審核動作は変更も一緒に保存。 */
  const patch = async (
    extra: Record<string, string>,
    busyKey: string,
    advance: boolean,
  ): Promise<boolean> => {
    if (!detail) return false;
    // 保存の直前に、表示中の記録と选中の記録が同じかを確かめる。
    if (detail.id !== recordId) { setActionError(t('record.mismatch')); return false; }
    setBusy(busyKey);
    setActionError(null);
    try {
      const updated = await updateRecord(detail.id, { ...changed, ...extra });
      setDetail(updated);
      setDraft({});
      // 共通の更新: 資料庫の各視図・照片云・関連にも反映（色は再計算しない）。
      ex.recordsChanged([detail.id]);
      onActioned(detail.id, advance);
      return true;
    } catch (e: unknown) {
      setActionError(e instanceof ApiError ? e.message : String(e));
      return false;
    } finally {
      setBusy(null);
    }
  };
  // 未保存の保護（侧栏・筛选・記録の切替・窓を閉じる）。保存は字段の変更だけ。
  useEditorGuard({
    kind: 'page',
    isDirty: () => dirty,
    save: () => (dirty ? patch({}, 'save', false) : Promise.resolve(true)),
    discard: () => setDraft({}),
  });

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
        <div className="rv-viewer-head">
          <div className="rv-id">{detail.DisplayID || detail.SignID}</div>
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
          <button type="button" className="rv-open" disabled={busy != null}
            title={t('review.openInDatabase')} aria-label={t('review.openInDatabase')}
            onClick={() => navigate(`/database?record=${detail.id}`)}>↗</button>
        </div>
        <div
          className="rv-photo"
          style={{ cursor: mainUrl ? 'zoom-in' : 'default' }}
          title={mainUrl ? t('review.zoomHint') : undefined}
          onClick={() => mainUrl && setLightbox(effView)}
        >
          {mainUrl
            ? <img src={mainUrl} alt={effView} />
            : <div className="muted">{t('review.noPhoto')}</div>}
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
        <div className="rv-fields-head">
          {/* 人の審核状態と、字段の記入状況は別のもの — 並べて別々に示す。 */}
          <span className="rv-k">{t('review.statusLabel')}</span>
          <StatusBadge value={detail.data.DataStatus || detail.DataStatus} />
          <span className="spacer" />
          <span className="rv-k">{t('review.completeness')}</span>
          <span className={`fill-meter${filledCount === allFields.length ? ' full' : ''}`}>
            {filledCount} / {allFields.length}
          </span>
        </div>
        <div className="rv-fields-scroll">
          {/* v6 定義表と同じ区分・順序（schema から派生）。状態はアクションボタン経由でのみ変更する。 */}
          {fieldGroups.map((g) => (
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
          <div className="rv-actions-row rv-nav">
            <button className="btn ghost icon" disabled={!nav.canPrev || busy != null} onClick={nav.onPrev}
              title={`${t('review.prev')} (K)`} aria-label={t('review.prev')}>
              ‹<kbd>K</kbd>
            </button>
            <span className="mono rv-pos">{nav.position || '—'} / {nav.total}</span>
            <button className="btn ghost icon" disabled={!nav.canNext || busy != null} onClick={nav.onNext}
              title={`${t('review.next')} (J)`} aria-label={t('review.next')}>
              ›<kbd>J</kbd>
            </button>
            <span className="spacer" />
            {dirty && <span className="dirty-note">{t('review.unsavedNote')}</span>}
            <button className="btn" disabled={!dirty || busy != null}
              onClick={() => patch({}, 'save', false)} title={t('review.saveHint')}>
              {busy === 'save' ? t('record.saving') : t('record.save')}
              <kbd>Ctrl S</kbd>
            </button>
          </div>
          {actionBtn('reviewed', 'primary rv-main-action', '1', t('review.actions.reviewedNext'))}
          <div className="rv-actions-row">
            {actionBtn('verified', '', '2')}
            {actionBtn('needs_review', 'accent', '3')}
            {actionBtn('rejected', 'danger', 'X')}
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
