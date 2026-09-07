import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { SchemaInfo } from '../../api/types';
import { enumLabel } from '../../lib/enumLabels';
import LanguageRoleSelector from './LanguageRoleSelector';

const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'reviewed', 'verified', 'rejected'];

// B 言語 3 字段は専用の選択器（検索追加・不明・無の状態モデル付き）。
// 文字体系は従来どおり ChipMulti。
const LANGUAGE_ROLE_FIELDS = ['主要言語', '補助言語', '装飾の言語'];

const splitMulti = (v: string) =>
  v.split(/[/・、,]/).map((s) => s.trim()).filter((s) => s && s !== '—');

/** 複数選択字段（主要言語等）のチップエディタ。値は「/」区切りで保存。 */
function ChipMulti({
  value,
  options,
  onChange,
}: {
  value: string;
  options: string[];
  onChange: (v: string) => void;
}) {
  const { t } = useTranslation();
  const selected = splitMulti(value);
  // 選択肢に無い自由追加値もチップとして出す（消せるように）。
  const all = [...options, ...selected.filter((s) => !options.includes(s))];
  const toggle = (o: string) => {
    const next = selected.includes(o)
      ? selected.filter((s) => s !== o)
      : [...selected, o];
    onChange(next.join('/'));
  };
  return (
    <div className="chip-row">
      {all.map((o) => (
        <button
          key={o}
          type="button"
          className={`chip${selected.includes(o) ? ' on' : ''}`}
          onClick={() => toggle(o)}
        >
          {enumLabel(t, o)}
        </button>
      ))}
    </div>
  );
}

const MONOLINGUAL = '单语型';

/** 多言語関係の 2 段入力（v6.1）: ①是否多语言 → ②多言語なら Reh の 4 類
    （复制/重复/部分翻译/互补）。保存は従来どおり 1 字段 1 値 — 单语型か
    4 類のどれか。「是否多语言」は値から導出できるため新列は作らない。 */
function MultilingualRelation({
  value,
  options,
  onChange,
}: {
  value: string;
  options: string[];
  onChange: (v: string) => void;
}) {
  const { t } = useTranslation();
  const multiOptions = options.filter((o) => o !== MONOLINGUAL);
  const isMono = value === MONOLINGUAL;
  // 4 類（or 旧自由値）なら多言語枝。空は未回答（どちらも未選択）。
  const isMulti = value !== '' && !isMono;
  // 「多言語」を押しただけで類型未選択の間は、値は空のまま枝だけ開いておく。
  const [multiOpen, setMultiOpen] = useState(false);
  const showMulti = isMulti || multiOpen;

  const chip = (key: string, label: string, on: boolean, onClick: () => void) => (
    <button
      key={key}
      type="button"
      role="checkbox"
      aria-checked={on}
      className={`chip${on ? ' on' : ''}`}
      onClick={onClick}
    >
      {on && <span aria-hidden="true">✓ </span>}
      {label}
    </button>
  );

  return (
    <div className="lang-sel">
      <div className="chip-row" role="group">
        {chip('mono', t('mlr.mono'), isMono, () => {
          setMultiOpen(false);
          onChange(isMono ? '' : MONOLINGUAL);
        })}
        {chip('multi', t('mlr.multi'), isMulti || multiOpen, () => {
          if (showMulti) {
            setMultiOpen(false);
            if (isMulti) onChange('');
          } else {
            setMultiOpen(true);
            if (isMono) onChange('');
          }
        })}
      </div>
      {showMulti && (
        <div className="chip-row" role="group" aria-label={t('mlr.typeLabel')}>
          {multiOptions.map((o) =>
            chip(o, enumLabel(t, o), value === o,
              () => onChange(value === o ? '' : o)))}
          {/* 選択肢に無い旧自由値も見えるように出す */}
          {isMulti && !multiOptions.includes(value) &&
            chip(value, enumLabel(t, value), true, () => onChange(''))}
        </div>
      )}
    </div>
  );
}

/** 1つの編集可能字段。型は schema（enums / multi_fields / status_values）で決める。 */
export default function FieldEditor({
  field,
  value,
  schema,
  onChange,
  textType,
}: {
  field: string;
  value: string;
  schema: SchemaInfo | null;
  onChange: (v: string) => void;
  /** 文字性の現在値（言語 3 字段の禁用判定用。親が current('文字性') を渡す） */
  textType?: string;
}) {
  const { t } = useTranslation();
  if (LANGUAGE_ROLE_FIELDS.includes(field)) {
    return (
      <LanguageRoleSelector
        field={field}
        value={value}
        presets={schema?.enums[field] ?? []}
        allowNone={field !== '主要言語'}
        disabled={textType === '記号' || textType === '対象外'}
        onChange={onChange}
      />
    );
  }
  if (field === '多言語関係') {
    return (
      <MultilingualRelation
        value={value}
        options={schema?.enums[field] ?? []}
        onChange={onChange}
      />
    );
  }
  if (field === '備考') {
    return (
      <textarea rows={3} value={value} onChange={(e) => onChange(e.target.value)} />
    );
  }
  if (field === '_status' || field === 'DataStatus') {
    // option の value は内部値のまま（PATCH に載る）。表示ラベルだけ翻訳する。
    const options =
      field === '_status' ? (schema?.status_values ?? []) : DATA_STATUSES;
    return (
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        {!options.includes(value) && <option value={value}>{value || '—'}</option>}
        {options.map((o) => (
          <option key={o} value={o}>{t(`status.${o}`, { defaultValue: o })}</option>
        ))}
      </select>
    );
  }
  if (schema?.multi_fields.includes(field)) {
    return (
      <ChipMulti value={value} options={schema.enums[field] ?? []} onChange={onChange} />
    );
  }
  const options = schema?.enums[field];
  if (options) {
    // option の value は正準値のまま（PATCH に載る）。表示ラベルだけ翻訳する。
    return (
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">—</option>
        {!options.includes(value) && value !== '' && (
          <option value={value}>{enumLabel(t, value)}</option>
        )}
        {options.map((o) => (
          <option key={o} value={o}>{enumLabel(t, o)}</option>
        ))}
      </select>
    );
  }
  return <input value={value} onChange={(e) => onChange(e.target.value)} />;
}
