import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getRecord, photoUrl, updateRecord } from '../../api/client';
import type { RecordDetail, SchemaInfo } from '../../api/types';
import { groupedResearchFields } from '../../lib/researchFields';
import { useEditorGuard } from '../../lib/unsavedGuard';
import LangTags from '../LangTags';
import PhotoLightbox from '../PhotoLightbox';
import FieldEditor from './FieldEditor';
import PhotoThumb from './PhotoThumb';
import StatusBadge from './StatusBadge';

// 只読で表示する識別情報（系統字段。backend 側でも編集がロックされている）。
// キーは**データの字段名そのもの**であり翻訳しない — 表示ラベルのみ i18n。
// DataStatus はここ（只読）にのみ出す — 編集は「状態(_status)」に一本化し、
// DataStatus は保存時に backend が自動同期する（v6 定義表の状態は 1 つ）。
const IDENTITY_FIELDS = [
  'SignID', 'CaptureID', 'DisplayID', '写真ファイル名', '元写真ファイル名',
  '採集者ID', '地区コード', '採集日時', '緯度', '経度',
  'EntryMode', 'DataStatus', 'SchemaVersion', 'AppVersion',
];

const SECTIONS_KEY = 'llmap.detailSections';
type SectionKey = 'research' | 'explore' | 'system';
const loadSections = (): Record<SectionKey, boolean> => {
  try {
    return { research: true, explore: true, system: false, ...JSON.parse(localStorage.getItem(SECTIONS_KEY) || '{}') };
  } catch { return { research: true, explore: true, system: false }; }
};

/** 記録の详情（どの視図から開いても同じもの）。層に分けて並べる:
    主（写真・言語・地点・編号・審核状態）→ 研究字段（編集）→ 探索（色板・関連）→ 系統情報。
    操作は明確な動詞で（编辑字段・进入审核・选中记录・导出・继续关联探索）。 */
export default function RecordDetailPanel({
  recordId,
  schema,
  onSaved,
  onClose,
  onDirtyChange,
  actions,
  explore,
  notice,
}: {
  recordId: number;
  schema: SchemaInfo | null;
  onSaved: (detail: RecordDetail) => void;
  /** 指定時は見出しに閉じるボタンを出す（抽屉）。 */
  onClose?: () => void;
  /** 未保存の変更の有無を親へ（閉じる・切替時の確認用）。 */
  onDirtyChange?: (dirty: boolean) => void;
  /** 操作の動詞（进入审核・选中记录・导出・继续关联探索）。编辑字段 はここで出す。 */
  actions?: ReactNode;
  /** 探索の区（色板・色の情報・関連）。 */
  explore?: ReactNode;
  /** 保存後の知らせ（例: 範囲に合わなくなった）。 */
  notice?: ReactNode;
}) {
  const { t } = useTranslation();
  const [detail, setDetail] = useState<RecordDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [lightbox, setLightbox] = useState<'crop' | 'source' | null>(null);
  const [sections, setSections] = useState(loadSections);
  const researchRef = useRef<HTMLDetailsElement>(null);
  const toggleSection = (k: SectionKey, open: boolean) => setSections((s) => {
    if (s[k] === open) return s;
    const next = { ...s, [k]: open };
    try { localStorage.setItem(SECTIONS_KEY, JSON.stringify(next)); } catch { /* 表示は切替わる */ }
    return next;
  });

  // 記録を読む。素早く切り替えたとき、前の記録の応答が後から届いても使わない
  // （開いている記録と編集中の記録が食い違わないように）。
  useEffect(() => {
    let stale = false;
    setDetail(null);
    setError(null);
    setDraft({});
    setSaveError(null);
    getRecord(recordId)
      .then((d) => { if (!stale && d.id === recordId) setDetail(d); })
      .catch((e: unknown) => {
        if (!stale) setError(e instanceof ApiError ? e.message : String(e));
      });
    return () => { stale = true; };
  }, [recordId]);

  const current = (field: string): string =>
    draft[field] ?? detail?.data[field] ?? '';

  const changed = useMemo(() => {
    if (!detail) return {};
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(draft)) {
      if (v !== (detail.data[k] ?? '')) out[k] = v;
    }
    return out;
  }, [draft, detail]);
  const dirty = Object.keys(changed).length > 0;
  useEffect(() => onDirtyChange?.(dirty), [dirty, onDirtyChange]);
  useEffect(() => () => onDirtyChange?.(false), [onDirtyChange]);

  const save = async (): Promise<boolean> => {
    if (!detail || !dirty) return true;
    // 保存の直前にも、表示中の記録と開いている記録が同じかを確かめる。
    if (detail.id !== recordId) { setSaveError(t('record.mismatch')); return false; }
    setSaving(true);
    setSaveError(null);
    try {
      const updated = await updateRecord(detail.id, changed);
      if (updated.id === recordId) {
        setDetail(updated);
        setDraft({});
      }
      onSaved(updated); // 一覧・地図・画布も更新する
      return true;
    } catch (e: unknown) {
      setSaveError(e instanceof ApiError ? e.message : String(e));
      return false;
    } finally {
      setSaving(false);
    }
  };
  // 未保存の保護（記録の切替・閉じる・窓を閉じる）。
  useEditorGuard({ kind: 'drawer', isDirty: () => dirty, save, discard: () => setDraft({}) });

  /** 「编辑字段」: 研究字段の区を開いて最初の入力へ。 */
  const editFields = () => {
    toggleSection('research', true);
    requestAnimationFrame(() => {
      const el = researchRef.current;
      el?.scrollIntoView({ block: 'start', behavior: 'smooth' });
      el?.querySelector<HTMLElement>('input, select, textarea, button.dd-trigger, [tabindex="0"]')?.focus({ preventScroll: true });
    });
  };

  // 字段の表示ラベル: 翻訳があれば使い、なければ字段キーをそのまま出す。
  const fieldLabel = (f: string) => t(`fields.${f}`, { defaultValue: f });

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

  // 読込中・失敗でも閉じられるように（Esc だけに頼らない）。
  const closeBtn = onClose && (
    <button type="button" className="btn ghost icon" onClick={onClose}
      title={t('common.close')} aria-label={t('common.close')}>✕</button>
  );
  if (error) {
    return (
      <div className="detail-panel card">
        <div className="detail-head"><span />{closeBtn}</div>
        <div className="error-box">
          <strong>{t('record.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      </div>
    );
  }
  if (!detail) {
    return (
      <div className="detail-panel card">
        <div className="detail-head"><span className="muted">{t('record.loading')}</span>{closeBtn}</div>
      </div>
    );
  }

  const lat = detail.data['緯度'];
  const lng = detail.data['経度'];
  const place = [detail.data['地区コード'], lat && lng ? `${Number(lat).toFixed(5)}, ${Number(lng).toFixed(5)}` : '']
    .filter(Boolean).join(' · ');

  return (
    <div className="detail-panel card dp">
      <div className="detail-head">
        <div>
          <div className="detail-title">{detail.DisplayID || detail.SignID}</div>
          <div className="muted mono" style={{ fontSize: 11.5 }}>{detail.SignID}</div>
        </div>
        <div className="detail-badges">
          <StatusBadge value={detail.data['DataStatus'] || ''} />
          {onClose && (
            <button type="button" className="btn ghost icon" onClick={onClose}
              title={t('common.close')} aria-label={t('common.close')}>✕</button>
          )}
        </div>
      </div>

      {/* 主: 裁切図を大きく（クリックで拡大・ドラッグ・復位。原図へも切替可）。 */}
      <div className="dp-photo">
        <button type="button" className="dp-photo-main" disabled={!detail.photoUrl}
          title={t('record.openFull')} onClick={() => setLightbox('crop')}>
          <PhotoThumb src={photoUrl(detail.photoUrl)} size={400} alt="crop" />
        </button>
        <div className="dp-photo-row">
          <span className="muted">{t('record.crop')}</span>
          <span className="spacer" />
          <button type="button" className="link-btn" disabled={!detail.sourcePhotoUrl}
            onClick={() => setLightbox('source')}>
            {detail.sourcePhotoUrl ? t('record.viewSource') : t('record.noSource')}
          </button>
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

      <dl className="dp-facts">
        <dt>{fieldLabel('主要言語')}</dt><dd><LangTags value={current('主要言語')} /></dd>
        <dt>{fieldLabel('補助言語')}</dt><dd><LangTags value={current('補助言語')} /></dd>
        <dt>{t('record.place')}</dt><dd className="mono">{place || '—'}</dd>
        <dt>{fieldLabel('採集日時')}</dt><dd className="mono">{detail.data['採集日時'] || '—'}</dd>
        <dt>{fieldLabel('_status')}</dt><dd>{t(`status.${detail.data['_status']}`, { defaultValue: detail.data['_status'] || '—' })}</dd>
      </dl>

      <div className="dp-actions">
        <button type="button" className="btn sm" onClick={editFields}>{t('record.editFields')}</button>
        {actions}
      </div>

      {notice}

      <details ref={researchRef} className="dp-section" open={sections.research}
        onToggle={(e) => toggleSection('research', (e.target as HTMLDetailsElement).open)}>
        <summary>
          {t('record.researchFields')}
          {dirty && <span className="dirty-flag">{t('record.unsaved')}</span>}
        </summary>
        {/* v6 定義表と同じ区分・順序。字段リストは schema から派生（ハードコードしない）。 */}
        {groupedResearchFields(schema).map((g) => (
          <div key={g.key}>
            <div className="dp-group">{t(`fields.group.${g.key}`)}</div>
            <div className="edit-grid">
              {g.fields.map((f) => (
                <label key={f} className="edit-row">
                  <span className="k">{fieldLabel(f)}</span>
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
        {/* 状態は 1 つだけ（v6 D 区の末尾）。DataStatus は backend が自動同期。 */}
        <div className="edit-grid" style={{ marginTop: 10 }}>
          <label className="edit-row">
            <span className="k">{fieldLabel('_status')}</span>
            <FieldEditor
              field="_status"
              value={current('_status')}
              schema={schema}
              onChange={(v) => setDraft((d) => ({ ...d, _status: v }))}
            />
          </label>
        </div>
      </details>

      {explore && (
        <details className="dp-section" open={sections.explore}
          onToggle={(e) => toggleSection('explore', (e.target as HTMLDetailsElement).open)}>
          <summary>{t('record.exploreSection')}</summary>
          {sections.explore && explore}
        </details>
      )}

      {/* 系統情報（ファイル名・版本など）は低頻度なので畳む。 */}
      <details className="dp-section" open={sections.system}
        onToggle={(e) => toggleSection('system', (e.target as HTMLDetailsElement).open)}>
        <summary>{t('record.identity')}</summary>
        <div className="identity-grid">
          {IDENTITY_FIELDS.map((f) => (
            <div key={f} className="identity-row">
              <span className="k">{fieldLabel(f)}</span>
              <span className="v mono">{detail.data[f] || '—'}</span>
            </div>
          ))}
        </div>
      </details>

      {saveError && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <strong>{t('record.saveFailed')}</strong>
          <div className="hint">{saveError}</div>
        </div>
      )}

      <div className="detail-actions dp-save">
        <button className="btn primary" disabled={!dirty || saving} onClick={() => void save()}>
          {saving ? t('record.saving') : t('record.save')}
        </button>
        <button className="btn" disabled={!dirty || saving} onClick={() => setDraft({})}>
          {t('common.cancel')}
        </button>
        <span className="spacer" />
        <span className="muted" style={{ fontSize: 11.5 }}>
          {dirty ? t('record.unsavedHint') : t('record.updated', { time: detail.updatedAt.slice(0, 19).replace('T', ' ') })}
        </span>
      </div>
    </div>
  );
}
