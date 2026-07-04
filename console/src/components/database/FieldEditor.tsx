import type { SchemaInfo } from '../../api/types';

const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'reviewed', 'verified', 'rejected'];

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
          {o}
        </button>
      ))}
    </div>
  );
}

/** 1つの編集可能字段。型は schema（enums / multi_fields / status_values）で決める。 */
export default function FieldEditor({
  field,
  value,
  schema,
  onChange,
}: {
  field: string;
  value: string;
  schema: SchemaInfo | null;
  onChange: (v: string) => void;
}) {
  if (field === '備考') {
    return (
      <textarea rows={3} value={value} onChange={(e) => onChange(e.target.value)} />
    );
  }
  if (field === '_status' || field === 'DataStatus') {
    const options =
      field === '_status' ? (schema?.status_values ?? []) : DATA_STATUSES;
    return (
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        {!options.includes(value) && <option value={value}>{value || '—'}</option>}
        {options.map((o) => (
          <option key={o} value={o}>{o}</option>
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
    return (
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">—</option>
        {!options.includes(value) && value !== '' && (
          <option value={value}>{value}</option>
        )}
        {options.map((o) => (
          <option key={o} value={o}>{o}</option>
        ))}
      </select>
    );
  }
  return <input value={value} onChange={(e) => onChange(e.target.value)} />;
}
