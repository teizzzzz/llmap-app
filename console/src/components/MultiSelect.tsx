import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';

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
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // 外側クリックで閉じる
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

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
    <div className="filter-field multi-field" ref={ref}>
      <span>{label}</span>
      <button
        type="button"
        className={`multi-trigger${selected.length ? ' has-value' : ''}`}
        onClick={() => setOpen((v) => !v)}
      >
        <span className="multi-summary">{summary}</span>
        <span className="multi-caret">▾</span>
      </button>
      {open && (
        <div className="multi-pop">
          <button
            type="button"
            className={`multi-all${selected.length === 0 ? ' on' : ''}`}
            onClick={() => onChange([])}
          >
            {t('common.all')}
          </button>
          {options.map((o) => (
            <label key={o.value} className="multi-opt" title={o.label}>
              <input
                type="checkbox"
                checked={selected.includes(o.value)}
                onChange={() => toggle(o.value)}
              />
              <span>{o.label}</span>
            </label>
          ))}
        </div>
      )}
    </div>
  );
}
