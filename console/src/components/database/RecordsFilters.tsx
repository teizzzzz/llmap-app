import { useEffect, useState } from 'react';
import type { Dataset, RecordsQuery } from '../../api/types';

export interface FilterOptions {
  languages: string[];
  areas: string[];
  collectors: string[];
  datasets: Dataset[];
}

const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'reviewed', 'verified', 'rejected'];

function Select({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <label className="filter-field">
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">All</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </label>
  );
}

/** yes/no/any の三値筛选（hasGps / hasPhoto / hasSourcePhoto 用）。 */
function TriState({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean | undefined;
  onChange: (v: boolean | undefined) => void;
}) {
  return (
    <label className="filter-field">
      <span>{label}</span>
      <select
        value={value === undefined ? '' : String(value)}
        onChange={(e) =>
          onChange(e.target.value === '' ? undefined : e.target.value === 'true')
        }
      >
        <option value="">All</option>
        <option value="true">Yes</option>
        <option value="false">No</option>
      </select>
    </label>
  );
}

/** 検索＋筛选バー。変更は即時 onChange（page リセットは親が行う）。 */
export default function RecordsFilters({
  value,
  options,
  total,
  onChange,
  onClear,
  onRefresh,
}: {
  value: RecordsQuery;
  options: FilterOptions;
  total: number | null;
  onChange: (patch: Partial<RecordsQuery>) => void;
  onClear: () => void;
  onRefresh: () => void;
}) {
  // q は打鍵のたびに叩かないよう 400ms デバウンス。
  const [q, setQ] = useState(value.q ?? '');
  useEffect(() => setQ(value.q ?? ''), [value.q]);
  useEffect(() => {
    const t = setTimeout(() => {
      if ((value.q ?? '') !== q) onChange({ q: q || undefined });
    }, 400);
    return () => clearTimeout(t);
  }, [q, value.q, onChange]);

  const opts = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));

  return (
    <div className="card filters-bar">
      <input
        className="filter-search"
        placeholder="Search SignID / CaptureID / DisplayID / text…"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      <Select label="Language" value={value.mainLanguage ?? ''}
        options={opts(options.languages)}
        onChange={(v) => onChange({ mainLanguage: v || undefined })} />
      <Select label="Area" value={value.areaCode ?? ''}
        options={opts(options.areas)}
        onChange={(v) => onChange({ areaCode: v || undefined })} />
      <Select label="Collector" value={value.collectorId ?? ''}
        options={opts(options.collectors)}
        onChange={(v) => onChange({ collectorId: v || undefined })} />
      <Select label="Mode" value={value.entryMode ?? ''}
        options={opts(ENTRY_MODES)}
        onChange={(v) => onChange({ entryMode: v || undefined })} />
      <Select label="Status" value={value.dataStatus ?? ''}
        options={opts(DATA_STATUSES)}
        onChange={(v) => onChange({ dataStatus: v || undefined })} />
      <Select label="Dataset" value={value.datasetId != null ? String(value.datasetId) : ''}
        options={options.datasets.map((d) => ({ value: String(d.id), label: `#${d.id} ${d.name}` }))}
        onChange={(v) => onChange({ datasetId: v ? Number(v) : undefined })} />
      <TriState label="GPS" value={value.hasGps}
        onChange={(v) => onChange({ hasGps: v })} />
      <TriState label="Photo" value={value.hasPhoto}
        onChange={(v) => onChange({ hasPhoto: v })} />
      <TriState label="Source" value={value.hasSourcePhoto}
        onChange={(v) => onChange({ hasSourcePhoto: v })} />
      <label className="filter-field">
        <span>From</span>
        <input type="date" value={value.dateFrom ?? ''}
          onChange={(e) => onChange({ dateFrom: e.target.value || undefined })} />
      </label>
      <label className="filter-field">
        <span>To</span>
        <input type="date" value={value.dateTo ?? ''}
          onChange={(e) => onChange({ dateTo: e.target.value || undefined })} />
      </label>
      <span className="spacer" />
      <span className="muted total">{total != null ? `${total} records` : ''}</span>
      <button className="btn" onClick={onClear}>Clear filters</button>
      <button className="btn" onClick={onRefresh}>Refresh</button>
    </div>
  );
}
