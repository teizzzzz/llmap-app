import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Dataset, RecordsQuery } from '../../api/types';
import { enumLabel } from '../../lib/enumLabels';
import MultiSelect from '../MultiSelect';

export interface FilterOptions {
  languages: string[];
  areas: string[];
  collectors: string[];
  datasets: Dataset[];
}

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
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
  const { t } = useTranslation();
  return (
    <label className="filter-field">
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">{t('common.all')}</option>
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
  const { t } = useTranslation();
  return (
    <label className="filter-field">
      <span>{label}</span>
      <select
        value={value === undefined ? '' : String(value)}
        onChange={(e) =>
          onChange(e.target.value === '' ? undefined : e.target.value === 'true')
        }
      >
        <option value="">{t('common.all')}</option>
        <option value="true">{t('common.yes')}</option>
        <option value="false">{t('common.no')}</option>
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
  const { t } = useTranslation();
  // q は打鍵のたびに叩かないよう 400ms デバウンス。
  const [q, setQ] = useState(value.q ?? '');
  useEffect(() => setQ(value.q ?? ''), [value.q]);
  useEffect(() => {
    const timer = setTimeout(() => {
      if ((value.q ?? '') !== q) onChange({ q: q || undefined });
    }, 400);
    return () => clearTimeout(timer);
  }, [q, value.q, onChange]);

  // データ由来の選択肢（地区・採集者）は原文のまま表示する。
  const opts = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  // 内部状態値は表示ラベルのみ翻訳する。
  const statusOpts = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));
  // 選択肢値（言語等）は value は正準値のまま、表示ラベルのみ翻訳する。
  const enumOpts = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: enumLabel(t, x) }));

  return (
    <div className="card filters-bar">
      <input
        className="filter-search"
        placeholder={t('filters.search')}
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      <Select label={t('filters.language')} value={value.mainLanguage ?? ''}
        options={enumOpts(options.languages)}
        onChange={(v) => onChange({ mainLanguage: v || undefined })} />
      <Select label={t('filters.area')} value={value.areaCode ?? ''}
        options={opts(options.areas)}
        onChange={(v) => onChange({ areaCode: v || undefined })} />
      <Select label={t('filters.collector')} value={value.collectorId ?? ''}
        options={opts(options.collectors)}
        onChange={(v) => onChange({ collectorId: v || undefined })} />
      <Select label={t('filters.mode')} value={value.entryMode ?? ''}
        options={statusOpts(ENTRY_MODES)}
        onChange={(v) => onChange({ entryMode: v || undefined })} />
      <Select label={t('filters.status')} value={value.dataStatus ?? ''}
        options={statusOpts(DATA_STATUSES)}
        onChange={(v) => onChange({ dataStatus: v || undefined })} />
      {/* データセットは多选（導出で複数データセットをまとめて出せる）。
          旧単値 datasetId が残っていたら選択済みとして表示し、以後は datasetIds に統一。 */}
      <MultiSelect label={t('filters.dataset')}
        options={options.datasets.map((d) => ({ value: String(d.id), label: `#${d.id} ${d.name}` }))}
        selected={(value.datasetIds ?? (value.datasetId != null ? [value.datasetId] : [])).map(String)}
        onChange={(vs) => onChange({
          datasetIds: vs.length ? vs.map(Number) : undefined,
          datasetId: undefined,
        })} />
      <TriState label={t('filters.gps')} value={value.hasGps}
        onChange={(v) => onChange({ hasGps: v })} />
      <TriState label={t('filters.photo')} value={value.hasPhoto}
        onChange={(v) => onChange({ hasPhoto: v })} />
      <TriState label={t('filters.source')} value={value.hasSourcePhoto}
        onChange={(v) => onChange({ hasSourcePhoto: v })} />
      <label className="filter-field">
        <span>{t('filters.from')}</span>
        <input type="date" value={value.dateFrom ?? ''}
          onChange={(e) => onChange({ dateFrom: e.target.value || undefined })} />
      </label>
      <label className="filter-field">
        <span>{t('filters.to')}</span>
        <input type="date" value={value.dateTo ?? ''}
          onChange={(e) => onChange({ dateTo: e.target.value || undefined })} />
      </label>
      <span className="spacer" />
      <span className="muted total">
        {total != null ? t('common.records', { n: total }) : ''}
      </span>
      <button className="btn" onClick={onClear}>{t('common.clearFilters')}</button>
      <button className="btn" onClick={onRefresh}>{t('common.refresh')}</button>
    </div>
  );
}
