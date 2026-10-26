import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

/** 筛选栏の 1 区画: 「ラベル 値 ▾」のボタン＋ポップオーバー。
    値が入っていると active（荧光）表示。panel は close を受け取る render 関数。 */
export function Dropdown({
  label,
  valueLabel,
  active,
  panel,
  className = '',
}: {
  label: string;
  valueLabel: string;
  active: boolean;
  panel: (close: () => void) => ReactNode;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);
  return (
    <div className={`dd ${active ? 'active' : ''} ${className}`} ref={ref}>
      <button type="button" className="dd-trigger" aria-expanded={open}
        onClick={() => setOpen((v) => !v)}>
        <span className="dd-label">{label}</span>
        <span className="dd-value">{valueLabel}</span>
        <span className="dd-caret" aria-hidden="true">▾</span>
      </button>
      {open && <div className="dd-pop">{panel(() => setOpen(false))}</div>}
    </div>
  );
}

/** 単一選択の Dropdown（「全部」＝ 空文字）。 */
export function SelectDropdown({
  label,
  value,
  options,
  onChange,
  className,
}: {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
  className?: string;
}) {
  const { t } = useTranslation();
  const current = options.find((o) => o.value === value);
  return (
    <Dropdown
      label={label}
      valueLabel={current ? current.label : t('common.all')}
      active={!!value}
      className={className}
      panel={(close) => (
        <div className="dd-list" role="listbox">
          {[{ value: '', label: t('common.all') }, ...options].map((o) => (
            <button key={o.value || '__all'} type="button" role="option"
              aria-selected={o.value === value}
              className={`dd-opt${o.value === value ? ' on' : ''}`}
              onClick={() => { onChange(o.value); close(); }}>
              {o.label}
            </button>
          ))}
        </div>
      )}
    />
  );
}
