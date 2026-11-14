import { useEffect, useRef, useState, type ReactNode } from 'react';

/** ボタン＋下に開くメニュー（外側クリック・Esc で閉じる）。 */
export default function MenuButton({
  label,
  className = 'btn',
  children,
}: {
  label: ReactNode;
  className?: string;
  /** メニュー項目。close を受け取る render 関数。 */
  children: (close: () => void) => ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    // Esc はメニューだけを閉じる（後ろの详情まで閉じない）。
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); setOpen(false); } };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);
  return (
    <div className="menu" ref={ref}>
      <button type="button" className={className} aria-haspopup="menu" aria-expanded={open}
        onClick={() => setOpen((v) => !v)}>
        {label}<span className="menu-caret" aria-hidden="true">▾</span>
      </button>
      {open && <div className="menu-pop" role="menu">{children(() => setOpen(false))}</div>}
    </div>
  );
}
