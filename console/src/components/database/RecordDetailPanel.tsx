import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getRecord, photoUrl, updateRecord } from '../../api/client';
import type { RecordDetail, SchemaInfo } from '../../api/types';
import { groupedResearchFields } from '../../lib/researchFields';
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

/** 詳情面板: 写真＋識別情報（只読）＋研究字段の編集（dirty/Save/Cancel）。 */
export default function RecordDetailPanel({
  recordId,
  schema,
  onSaved,
}: {
  recordId: number;
  schema: SchemaInfo | null;
  onSaved: () => void;
}) {
  const { t } = useTranslation();
  const [detail, setDetail] = useState<RecordDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [lightbox, setLightbox] = useState<'crop' | 'source' | null>(null);

  const load = (id: number) => {
    setDetail(null);
    setError(null);
    setDraft({});
    setSaveError(null);
    getRecord(id)
      .then(setDetail)
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)));
  };
  useEffect(() => load(recordId), [recordId]);

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

  const save = async () => {
    if (!detail || !dirty) return;
    setSaving(true);
    setSaveError(null);
    try {
      const updated = await updateRecord(detail.id, changed);
      setDetail(updated);
      setDraft({});
      onSaved(); // 表格側の行も更新する
    } catch (e: unknown) {
      setSaveError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setSaving(false);
    }
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

  if (error) {
    return (
      <div className="detail-panel card">
        <div className="error-box">
          <strong>{t('record.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      </div>
    );
  }
  if (!detail) {
    return <div className="detail-panel card muted">{t('record.loading')}</div>;
  }

  return (
    <div className="detail-panel card">
      <div className="detail-head">
        <div>
          <div className="detail-title">{detail.DisplayID || detail.SignID}</div>
          <div className="muted mono" style={{ fontSize: 11.5 }}>{detail.SignID}</div>
        </div>
        <div className="detail-badges">
          <StatusBadge value={detail.EntryMode} />
          <StatusBadge value={current('DataStatus')} />
        </div>
      </div>

      {/* 写真（裁切図＋元写真）。クリックで統一ビューアを開く。 */}
      <div className="photo-pair">
        <figure
          style={{ cursor: detail.photoUrl ? 'zoom-in' : 'default' }}
          title={t('record.openFull')}
          onClick={() => detail.photoUrl && setLightbox('crop')}
        >
          <PhotoThumb src={photoUrl(detail.photoUrl)} size={170} alt="crop" />
          <figcaption className="muted">{t('record.crop')}</figcaption>
        </figure>
        <figure
          style={{ cursor: detail.sourcePhotoUrl ? 'zoom-in' : 'default' }}
          title={t('record.openFull')}
          onClick={() => detail.sourcePhotoUrl && setLightbox('source')}
        >
          <PhotoThumb src={photoUrl(detail.sourcePhotoUrl)} size={170} alt="source" />
          <figcaption className="muted">{t('record.source')}</figcaption>
        </figure>
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

      <h3 className="detail-section">{t('record.identity')}</h3>
      <div className="identity-grid">
        {IDENTITY_FIELDS.map((f) => (
          <div key={f} className="identity-row">
            <span className="k">{fieldLabel(f)}</span>
            <span className="v mono">{detail.data[f] || '—'}</span>
          </div>
        ))}
      </div>

      <h3 className="detail-section">
        {t('record.researchFields')}{' '}
        {dirty && <span className="dirty-flag">{t('record.unsaved')}</span>}
      </h3>
      {/* v6 定義表と同じ区分・順序。字段リストは schema から派生（ハードコードしない）。 */}
      {groupedResearchFields(schema).map((g) => (
        <div key={g.key}>
          <div className="muted" style={{ margin: '10px 0 4px', fontSize: 12, fontWeight: 600 }}>
            {t(`fields.group.${g.key}`)}
          </div>
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

      {saveError && (
        <div className="error-box" style={{ marginTop: 10 }}>
          <strong>{t('record.saveFailed')}</strong>
          <div className="hint">{saveError}</div>
        </div>
      )}

      <div className="detail-actions">
        <button className="btn primary" disabled={!dirty || saving} onClick={save}>
          {saving ? t('record.saving') : t('record.save')}
        </button>
        <button className="btn" disabled={!dirty || saving} onClick={() => setDraft({})}>
          {t('common.cancel')}
        </button>
        <span className="spacer" />
        <span className="muted" style={{ fontSize: 11.5 }}>
          {t('record.updated', { time: detail.updatedAt.slice(0, 19).replace('T', ' ') })}
        </span>
      </div>
    </div>
  );
}
