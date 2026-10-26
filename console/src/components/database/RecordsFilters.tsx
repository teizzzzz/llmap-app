import { useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { getRecords } from '../../api/client';
import type { Dataset, RecordsQuery } from '../../api/types';
import { enumLabel } from '../../lib/enumLabels';
import { Dropdown, SelectDropdown } from '../Dropdown';
import MultiSelect from '../MultiSelect';

export interface FilterOptions {
  languages: string[];
  areas: string[];
  collectors: string[];
  datasets: Dataset[];
}

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review', 'reviewed', 'verified', 'rejected'];

// 「更多筛选」に出す研究字段（字段表の枚挙字段すべて、定義表のグループ順）。
// 言語3役・文字体系は複数選択字段のため含有判定（backend の MULTI_FIELDS と同じ規則）。
const FIELD_FILTER_GROUPS: { group: string; keys: string[] }[] = [
  { group: 'B', keys: ['文字性', '主要言語', '補助言語', '装飾の言語', '文字体系', '多言語関係'] },
  { group: 'C', keys: ['担体類型', '放置位置', '空間階層', '時間性', '可読性', '重ね書き'] },
  { group: 'D', keys: ['設置主体', 'ディスコース類型', '製作品質'] },
];

type Chip = { key: string; label: string; remove: Partial<RecordsQuery> };

/** 検索＋筛选バー。常用 4 項目を 1 行に、残りは「更多筛选」に畳む。
    適用中の条件は chip で一覧し、クリックでその条件だけ外せる。
    変更は即時 onChange（page リセットは親が行う）。 */
export default function RecordsFilters({
  value,
  options,
  total,
  onChange,
  onClear,
  schemaEnums,
  fieldPresence,
  hideDatasets,
  trailing,
}: {
  value: RecordsQuery;
  options: FilterOptions;
  total: number | null;
  onChange: (patch: Partial<RecordsQuery>) => void;
  onClear: () => void;
  /** 旧 API 互換（自動再取得になったため未使用）。 */
  onRefresh?: () => void;
  /** 字段筛选の選択肢（/schema の enums）。 */
  schemaEnums?: Record<string, string[]> | null;
  /** 字段ごとの非空記録数（/stats/fields）。0 の字段は隠す。 */
  fieldPresence?: Record<string, number> | null;
  /** データセット筛选を隠す（対象が固定の文脈用）。 */
  hideDatasets?: boolean;
  /** chip 行の右側に置く追加操作（相册の縮略図サイズ等）。 */
  trailing?: ReactNode;
}) {
  const { t } = useTranslation();
  const fieldFilters = value.fields ?? {};
  const [showMore, setShowMore] = useState(false);

  // 全件数（「1987 / 2029」の分母）。
  const [grand, setGrand] = useState<number | null>(null);
  useEffect(() => {
    getRecords({ page: 1, pageSize: 1 }).then((r) => setGrand(r.total)).catch(() => {});
  }, []);

  // q は打鍵のたびに叩かないよう 400ms デバウンス。
  const [q, setQ] = useState(value.q ?? '');
  useEffect(() => setQ(value.q ?? ''), [value.q]);
  useEffect(() => {
    const timer = setTimeout(() => {
      if ((value.q ?? '') !== q) onChange({ q: q || undefined });
    }, 400);
    return () => clearTimeout(timer);
  }, [q, value.q, onChange]);

  const setField = (key: string, v: string) => {
    const next = { ...fieldFilters };
    if (v) next[key] = v;
    else delete next[key];
    onChange({ fields: Object.keys(next).length ? next : undefined });
  };

  const raw = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  const statusOpts = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));
  const enumOpts = (xs: string[]) => xs.map((x) => ({ value: x, label: enumLabel(t, x) }));
  const ynOpts = [
    { value: 'true', label: t('common.yes') },
    { value: 'false', label: t('common.no') },
  ];
  const yn = (v: boolean | undefined) => (v === undefined ? '' : String(v));
  const fromYn = (v: string) => (v === '' ? undefined : v === 'true');

  const datasetIds = value.datasetIds ?? (value.datasetId != null ? [value.datasetId] : []);
  const chip = (k: string, v: string) => t('filters.chip', { k, v });

  // 適用中の条件 → chip。
  const chips: Chip[] = [];
  if (value.q) chips.push({ key: 'q', label: chip(t('filters.keyword'), value.q), remove: { q: undefined } });
  if (value.mainLanguage) chips.push({ key: 'lang', label: chip(t('filters.language'), enumLabel(t, value.mainLanguage)), remove: { mainLanguage: undefined } });
  if (value.dataStatus) chips.push({ key: 'status', label: chip(t('filters.status'), t(`status.${value.dataStatus}`, { defaultValue: value.dataStatus })), remove: { dataStatus: undefined } });
  if (value.areaCode) chips.push({ key: 'area', label: chip(t('filters.area'), value.areaCode), remove: { areaCode: undefined } });
  if (value.dateFrom || value.dateTo) chips.push({ key: 'date', label: chip(t('filters.date'), `${value.dateFrom ?? '…'} — ${value.dateTo ?? '…'}`), remove: { dateFrom: undefined, dateTo: undefined } });
  if (value.collectorId) chips.push({ key: 'collector', label: chip(t('filters.collector'), value.collectorId), remove: { collectorId: undefined } });
  if (value.entryMode) chips.push({ key: 'mode', label: chip(t('filters.mode'), t(`status.${value.entryMode}`, { defaultValue: value.entryMode })), remove: { entryMode: undefined } });
  for (const id of datasetIds) {
    const ds = options.datasets.find((d) => d.id === id);
    const rest = datasetIds.filter((x) => x !== id);
    chips.push({ key: `ds-${id}`, label: chip(t('filters.dataset'), ds ? ds.name : `#${id}`), remove: { datasetIds: rest.length ? rest : undefined, datasetId: undefined } });
  }
  for (const [k, label] of [['hasGps', 'filters.gps'], ['hasPhoto', 'filters.photo'], ['hasSourcePhoto', 'filters.source']] as const) {
    const v = value[k];
    if (v !== undefined) chips.push({ key: k, label: chip(t(label), t(v ? 'common.yes' : 'common.no')), remove: { [k]: undefined } });
  }
  for (const [k, v] of Object.entries(fieldFilters)) {
    const rest = { ...fieldFilters };
    delete rest[k];
    chips.push({ key: `f-${k}`, label: chip(t(`fields.${k}`, { defaultValue: k }), enumLabel(t, v)), remove: { fields: Object.keys(rest).length ? rest : undefined } });
  }
  const primaryKeys = new Set(['q', 'lang', 'status', 'area', 'date']);
  const moreCount = chips.filter((c) => !primaryKeys.has(c.key)).length;

  return (
    <div className="fbar">
      <div className="fbar-row">
        <label className="fbar-search">
          <span aria-hidden="true">⌕</span>
          <input placeholder={t('filters.search')} value={q} onChange={(e) => setQ(e.target.value)} />
        </label>
        <SelectDropdown label={t('filters.language')} value={value.mainLanguage ?? ''}
          options={enumOpts(options.languages)}
          onChange={(v) => onChange({ mainLanguage: v || undefined })} />
        <SelectDropdown label={t('filters.status')} value={value.dataStatus ?? ''}
          options={statusOpts(DATA_STATUSES)}
          onChange={(v) => onChange({ dataStatus: v || undefined })} />
        <SelectDropdown label={t('filters.area')} value={value.areaCode ?? ''}
          options={raw(options.areas)}
          onChange={(v) => onChange({ areaCode: v || undefined })} />
        <Dropdown
          label={t('filters.date')}
          valueLabel={value.dateFrom || value.dateTo
            ? `${(value.dateFrom ?? '').slice(5).replace('-', '.') || '…'} — ${(value.dateTo ?? '').slice(5).replace('-', '.') || '…'}`
            : t('common.all')}
          active={!!(value.dateFrom || value.dateTo)}
          panel={() => (
            <div className="dd-dates">
              <label>{t('filters.from')}
                <input type="date" value={value.dateFrom ?? ''}
                  onChange={(e) => onChange({ dateFrom: e.target.value || undefined })} />
              </label>
              <label>{t('filters.to')}
                <input type="date" value={value.dateTo ?? ''}
                  onChange={(e) => onChange({ dateTo: e.target.value || undefined })} />
              </label>
            </div>
          )}
        />
        <button type="button" className={`fbar-more-btn${showMore ? ' open' : ''}`}
          aria-expanded={showMore} onClick={() => setShowMore((s) => !s)}>
          {t('filters.more')}
          {moreCount > 0 && <span className="fbar-more-n">{moreCount}</span>}
        </button>
      </div>

      {showMore && (
        <div className="fbar-more">
          <div className="fbar-more-row">
            <SelectDropdown label={t('filters.collector')} value={value.collectorId ?? ''}
              options={raw(options.collectors)}
              onChange={(v) => onChange({ collectorId: v || undefined })} />
            <SelectDropdown label={t('filters.mode')} value={value.entryMode ?? ''}
              options={statusOpts(ENTRY_MODES)}
              onChange={(v) => onChange({ entryMode: v || undefined })} />
            {!hideDatasets && (
              <MultiSelect label={t('filters.dataset')}
                options={options.datasets.map((d) => ({ value: String(d.id), label: `#${d.id} ${d.name}` }))}
                selected={datasetIds.map(String)}
                onChange={(vs) => onChange({
                  datasetIds: vs.length ? vs.map(Number) : undefined,
                  datasetId: undefined,
                })} />
            )}
            <SelectDropdown label={t('filters.gps')} value={yn(value.hasGps)} options={ynOpts}
              onChange={(v) => onChange({ hasGps: fromYn(v) })} />
            <SelectDropdown label={t('filters.photo')} value={yn(value.hasPhoto)} options={ynOpts}
              onChange={(v) => onChange({ hasPhoto: fromYn(v) })} />
            <SelectDropdown label={t('filters.source')} value={yn(value.hasSourcePhoto)} options={ynOpts}
              onChange={(v) => onChange({ hasSourcePhoto: fromYn(v) })} />
          </div>
          {schemaEnums && FIELD_FILTER_GROUPS.map(({ group, keys }) => {
            // 選択肢が定義されていて、かつ実データに値がある字段だけ出す。
            // ただし現に筛选中の字段は隠さない（解除できなくなるため）。
            const present = keys.filter((k) =>
              schemaEnums[k]?.length
              && ((fieldPresence?.[k] ?? 1) > 0 || fieldFilters[k]));
            if (!present.length) return null;
            return (
              <div key={group} className="fbar-more-row">
                {present.map((k) => (
                  <SelectDropdown key={k}
                    label={t(`fields.${k}`, { defaultValue: k })}
                    value={fieldFilters[k] ?? ''}
                    options={enumOpts(schemaEnums[k])}
                    onChange={(v) => setField(k, v)} />
                ))}
              </div>
            );
          })}
        </div>
      )}

      <div className="fbar-chips">
        {chips.map((c) => (
          <button key={c.key} type="button" className="chip removable" onClick={() => onChange(c.remove)}>
            {c.label}<span aria-hidden="true">×</span>
          </button>
        ))}
        {chips.length > 0 && (
          <button type="button" className="btn ghost" onClick={onClear}>{t('filters.clearAll')}</button>
        )}
        <span className="spacer" />
        {trailing}
        <span className="fbar-count mono">
          {total != null ? total : '—'}{grand != null && ` / ${grand}`}
        </span>
      </div>
    </div>
  );
}
