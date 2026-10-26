import { useTranslation } from 'react-i18next';
import { Dropdown } from './Dropdown';

/** 筛选栏用のチェックボックス式多选ドロップダウン（データセット多选等）。
    選択なし＝「全部」。选択 1 件はラベルを、複数は件数を表示する。 */
export default function MultiSelect({
  label,
  options,
  selected,
  onChange,
}: {
  label: string;
  options: { value: string; label: string }[];
  selected: string[];
  onChange: (next: string[]) => void;
}) {
  const { t } = useTranslation();
  const toggle = (v: string) =>
    onChange(selected.includes(v)
      ? selected.filter((x) => x !== v)
      : [...selected, v]);

  const summary =
    selected.length === 0
      ? t('common.all')
      : selected.length === 1
        ? options.find((o) => o.value === selected[0])?.label ?? selected[0]
        : t('filters.nSelected', { n: selected.length });

  return (
    <Dropdown
      label={label}
      valueLabel={summary}
      active={selected.length > 0}
      panel={() => (
        <div className="dd-list">
          <button type="button" className={`dd-opt${selected.length === 0 ? ' on' : ''}`}
            onClick={() => onChange([])}>
            {t('common.all')}
          </button>
          {options.map((o) => (
            <label key={o.value} className="dd-check" title={o.label}>
              <input type="checkbox" checked={selected.includes(o.value)}
                onChange={() => toggle(o.value)} />
              <span>{o.label}</span>
            </label>
          ))}
        </div>
      )}
    />
  );
}
