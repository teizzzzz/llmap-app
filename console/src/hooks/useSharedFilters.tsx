import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { RecordsQuery } from '../api/types';

// 数据库（表格・相册）と导出で共有する筛选条件。
// 数据库で絞った結果をそのまま导出へ持ち込めるよう、ページ遷移しても保持する。

interface SharedFilters {
  filters: RecordsQuery;
  patch: (p: Partial<RecordsQuery>) => void;
  replace: (q: RecordsQuery) => void;
  clear: () => void;
}

const Ctx = createContext<SharedFilters | null>(null);

export function SharedFiltersProvider({ children }: { children: ReactNode }) {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const patch = useCallback(
    (p: Partial<RecordsQuery>) => setFilters((f) => ({ ...f, ...p })), []);
  const clear = useCallback(() => setFilters({}), []);
  const value = useMemo(
    () => ({ filters, patch, replace: setFilters, clear }),
    [filters, patch, clear],
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
