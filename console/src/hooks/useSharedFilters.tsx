import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { RecordsQuery } from '../api/types';

// 資料庫（表格・相册）で決めた「範囲」を、審核・AI・導出へ引き継ぐ共有状態。
// 範囲は 2 種類あり、混ぜずに区別する:
//   filters   … 現在の筛选条件（結果すべて）
//   selection … 手動で選んだ記録の id（批量操作用。筛选とは独立）
// ページを移っても保持する。

interface SharedFilters {
  filters: RecordsQuery;
  patch: (p: Partial<RecordsQuery>) => void;
  replace: (q: RecordsQuery) => void;
  clear: () => void;
  selection: number[];
  toggleSelect: (id: number) => void;
  setSelection: (ids: number[]) => void;
  clearSelection: () => void;
}

const Ctx = createContext<SharedFilters | null>(null);

export function SharedFiltersProvider({ children }: { children: ReactNode }) {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [selection, setSelection] = useState<number[]>([]);
  const patch = useCallback(
    (p: Partial<RecordsQuery>) => setFilters((f) => ({ ...f, ...p })), []);
  const clear = useCallback(() => setFilters({}), []);
  const toggleSelect = useCallback((id: number) =>
    setSelection((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id])), []);
  const clearSelection = useCallback(() => setSelection([]), []);
  const value = useMemo(
    () => ({
      filters, patch, replace: setFilters, clear,
      selection, toggleSelect, setSelection, clearSelection,
    }),
    [filters, patch, clear, selection, toggleSelect, clearSelection],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export default function useSharedFilters(): SharedFilters {
  const v = useContext(Ctx);
  if (!v) throw new Error('useSharedFilters は SharedFiltersProvider の内側で使う');
  return v;
}

/** 条件が 1 つでも入っているか（undefined / 空文字は無条件扱い）。 */
export const hasAnyFilter = (q: RecordsQuery): boolean =>
  Object.values(q).some((v) => v !== undefined && v !== '');

/** 範囲の種類（URL の ?scope=）: db = 資料庫の筛选結果、sel = 手動選択。 */
export type ScopeKind = 'db' | 'sel';

/** 範囲 → API に渡す条件。選択は id だけで決まる（筛选とは混ぜない）。 */
export const scopeQuery = (
  kind: ScopeKind, filters: RecordsQuery, selection: number[],
): RecordsQuery => (kind === 'sel' ? { ids: selection } : { ...filters });
