import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

// 未保存の保護を 1 か所にまとめる。編集中のもの（記録の详情・審核の字段欄）は
// useEditorGuard で登録し、編集対象を離れるあらゆる操作（侧栏・筛选・記録の切替・
// 抽屉を閉じる・窓を閉じる）は confirmLeave() を通す。未保存があれば
// 「保存して続ける／変更を破棄／キャンセル」を尋ねる。

/** drawer = 記録の详情（どのページの上にも残る）、page = ページ内の編集（審核の字段欄）。 */
export type GuardKind = 'drawer' | 'page';

export interface EditorGuard {
  kind: GuardKind;
  isDirty: () => boolean;
  /** 保存する。成功なら true（失敗したら離れない）。 */
  save: () => Promise<boolean>;
  /** 変更を捨てる（下書きを空に）。 */
  discard: () => void;
}

const editors = new Map<number, React.MutableRefObject<EditorGuard>>();
let seq = 1;

type Choice = 'save' | 'discard' | 'cancel';
let ask: (() => Promise<Choice>) | null = null;
let pending: Promise<boolean> | null = null;

/** 未保存があれば尋ねる。離れてよければ true。同時に呼ばれても尋ねるのは 1 回。
    kind を渡すとその種類の編集だけを見る（例: 抽屉の記録切替は详情だけ、侧栏はページの編集）。 */
export function confirmLeave(kind?: GuardKind): Promise<boolean> {
  const dirty = [...editors.values()].filter((e) => (!kind || e.current.kind === kind) && e.current.isDirty());
  if (!dirty.length) return Promise.resolve(true);
  if (pending) return pending;
  pending = (async () => {
    try {
      const choice = ask ? await ask() : (window.confirm('Discard unsaved changes?') ? 'discard' : 'cancel');
      if (choice === 'cancel') return false;
      if (choice === 'discard') { dirty.forEach((e) => e.current.discard()); return true; }
      for (const e of dirty) if (!(await e.current.save())) return false;
      return true;
    } finally {
      pending = null;
    }
  })();
  return pending;
}

export const hasUnsaved = () => [...editors.values()].some((e) => e.current.isDirty());

/** 編集中のものを登録する（表示されている間）。最新の関数を ref で読む。 */
export function useEditorGuard(guard: EditorGuard): void {
  const ref = useRef(guard);
  ref.current = guard;
  useEffect(() => {
    const id = seq++;
    editors.set(id, ref);
    return () => { editors.delete(id); };
  }, []);
}

/** 確認の対話（1 つ）と、窓を閉じる・再読込するときの保護。App に 1 つ置く。 */
export function UnsavedGuardProvider({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const resolver = useRef<((c: Choice) => void) | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    ask = () => new Promise<Choice>((resolve) => {
      resolver.current = resolve;
      setOpen(true);
    });
    return () => { ask = null; };
  }, []);

  // 桌面版: 窓の × は shell が一度止めてここへ聞きに来る（未保存が無ければすぐ閉じる）。
  // ブラウザ: 再読込・タブを閉じるときは標準の確認。
  useEffect(() => {
    const w = window as unknown as {
      __llmapRequestClose?: () => void;
      __TAURI_INTERNALS__?: { invoke: (cmd: string) => Promise<unknown> };
    };
    w.__llmapRequestClose = () => {
      void confirmLeave().then((ok) => {
        if (ok) void w.__TAURI_INTERNALS__?.invoke('llmap_confirm_close');
      });
    };
    const onBefore = (e: BeforeUnloadEvent) => {
      if (!hasUnsaved()) return;
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', onBefore);
    return () => {
      delete w.__llmapRequestClose;
      window.removeEventListener('beforeunload', onBefore);
    };
  }, []);

  const choose = useCallback((c: Choice) => {
    if (c === 'save') setSaving(true);
    const r = resolver.current;
    resolver.current = null;
    setOpen(false);
    setSaving(false);
    r?.(c);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); choose('cancel'); } };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [open, choose]);

  return (
    <>
      {children}
      {open && (
        <div className="modal-overlay guard-overlay" role="presentation">
          <div className="modal guard-modal" role="alertdialog" aria-modal="true" aria-labelledby="guard-t">
            <h2 id="guard-t">{t('guard.title')}</h2>
            <p className="muted">{t('guard.body')}</p>
            <div className="guard-actions">
              <button type="button" className="btn ghost" onClick={() => choose('cancel')}>{t('guard.cancel')}</button>
              <span className="spacer" />
              <button type="button" className="btn danger" onClick={() => choose('discard')}>{t('guard.discard')}</button>
              {/* 既定は「保存して続ける」（Enter）。 */}
              <button type="button" className="btn primary" autoFocus disabled={saving} onClick={() => choose('save')}>
                {t('guard.save')}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
