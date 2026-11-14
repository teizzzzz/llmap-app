import {
  createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode,
} from 'react';
import { confirmLeave } from '../../lib/unsavedGuard';

// 記録の详情（抽屉）は 1 つだけ。照片・表格・地図・照片云・主题・関係画布の
// どこから開いても同じ详情を使う（ここは「どの記録を開いているか」だけ）。
// 未保存の保護は共通の確認（保存して続ける／破棄／キャンセル）。
interface DrawerState {
  /** 開いている記録（なければ null）。 */
  current: number | null;
  open: (id: number) => Promise<void>;
  /** 閉じる（未保存なら確認。閉じたら true）。 */
  close: () => Promise<boolean>;
}

const Ctx = createContext<DrawerState | null>(null);

export function RecordDrawerProvider({ children }: { children: ReactNode }) {
  const [current, setCurrent] = useState<number | null>(null);
  const curRef = useRef<number | null>(null);
  curRef.current = current;
  const open = useCallback(async (id: number) => {
    if (curRef.current === id) return;
    if (curRef.current != null && !(await confirmLeave('drawer'))) return;
    curRef.current = id;
    setCurrent(id);
  }, []);
  const close = useCallback(async () => {
    if (!(await confirmLeave('drawer'))) return false;
    curRef.current = null;
    setCurrent(null);
    return true;
  }, []);
  const value = useMemo(() => ({ current, open, close }), [current, open, close]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useRecordDrawer(): DrawerState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useRecordDrawer は RecordDrawerProvider の内側で使う');
  return v;
}
