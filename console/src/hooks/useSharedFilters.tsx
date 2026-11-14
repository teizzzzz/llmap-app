import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { RecordsQuery } from '../api/types';

// 資料庫の「範囲」— どの視図（照片・表格・地図・照片云・色彩）でも、審核・AI・導出でも
// 同じものを使う共有状態。3 種類を混ぜずに区別する:
//   filters   … 研究の筛选条件（結果すべて）。filters.setKey があれば記録集合と AND。
//   scopeSet  … 記録集合（主题・関連・探索の色や言語の条件など、筛选にできない範囲を
//               明確な記録の集まりにしたもの）。名前と採用した条件を持つ。
//   selection … 手動で選んだ記録の id（批量操作用。筛选とは独立）
// 主题・関連へ入るときは直前の範囲を back に積み、「返回」で範囲と画面・位置を戻す。

/** 記録集合（範囲として使う明確な記録の集まり）。 */
export interface ScopeSet {
  key: string;
  count: number;
  /** 例: 主题「中文红色招牌」/ 与 XXX 颜色相近 */
  label: string;
  /** 採用した条件（表示用。研究の筛选に置き換えられないもの）。 */
  conds: string[];
  origin: 'theme' | 'relation' | 'explore' | 'selection';
}

/** 「返回」で戻る先（範囲・画面・閲覧位置）。 */
export interface BackEntry {
  filters: RecordsQuery;
  set: ScopeSet | null;
  /** 戻る画面（例: /database?view=cloud） */
  path: string;
  /** 戻り先の説明（例: 全部资料 / 主题「…」） */
  label: string;
  /** 画布の状態（探索内の条件・カメラ位置）。 */
  snapshot?: unknown;
}

interface SharedFilters {
  filters: RecordsQuery;
  patch: (p: Partial<RecordsQuery>) => void;
  /** 範囲を丸ごと置き換える（記録集合も外す。例: 本次导入分）。 */
  replace: (q: RecordsQuery) => void;
  /** 研究の筛选だけを外す（記録集合は残す —— 外すのは集合の × から）。 */
  clear: () => void;
  scopeSet: ScopeSet | null;
  /** 記録集合を範囲にする。keepFilters=false なら研究の筛选も外す（主题・関連は別の入口）。
      back を渡すと、今の範囲をその説明つきで「返回」先に積む。 */
  applySet: (set: ScopeSet, opts?: { keepFilters?: boolean; back?: Omit<BackEntry, 'filters' | 'set'> }) => void;
  clearSet: () => void;
  backStack: BackEntry[];
  /** 直前の範囲へ戻す（戻り先を返す。画面・位置の復元は呼び出し側）。 */
  goBack: () => BackEntry | null;
  selection: number[];
  toggleSelect: (id: number) => void;
  setSelection: (ids: number[]) => void;
  clearSelection: () => void;
  /** 記録が編集されるたびに増える（各視図はこれで読み直す）。 */
  dataVersion: number;
  bumpData: () => void;
}

const Ctx = createContext<SharedFilters | null>(null);

export function SharedFiltersProvider({ children }: { children: ReactNode }) {
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [scopeSet, setScopeSet] = useState<ScopeSet | null>(null);
  const [backStack, setBackStack] = useState<BackEntry[]>([]);
  const [selection, setSelection] = useState<number[]>([]);
  const [dataVersion, setDataVersion] = useState(0);

  const patch = useCallback((p: Partial<RecordsQuery>) => {
    // 集合を外す patch（{setKey: undefined}）なら集合の情報も消す。
    if ('setKey' in p && !p.setKey) setScopeSet(null);
    setFilters((f) => ({ ...f, ...p }));
  }, []);
  const replace = useCallback((q: RecordsQuery) => {
    setScopeSet(q.setKey ? (s) => (s?.key === q.setKey ? s : null) : null);
    setFilters(q);
  }, []);
  const clear = useCallback(() => setFilters((f) => (f.setKey ? { setKey: f.setKey } : {})), []);
  const clearSet = useCallback(() => {
    setScopeSet(null);
    setFilters((f) => ({ ...f, setKey: undefined }));
  }, []);

  const applySet = useCallback<SharedFilters['applySet']>((set, opts) => {
    if (opts?.back) {
      const entry = { ...opts.back, filters, set: scopeSet };
      setBackStack((b) => [...b.slice(-19), entry]);
    }
    setScopeSet(set);
    setFilters((f) => (opts?.keepFilters ? { ...f, setKey: set.key } : { setKey: set.key }));
  }, [filters, scopeSet]);

  const goBack = useCallback((): BackEntry | null => {
    const last = backStack[backStack.length - 1];
    if (!last) return null;
    setBackStack((b) => b.slice(0, -1));
    setFilters(last.filters);
    setScopeSet(last.set);
    return last;
  }, [backStack]);

  const toggleSelect = useCallback((id: number) =>
    setSelection((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id])), []);
  const clearSelection = useCallback(() => setSelection([]), []);
  const bumpData = useCallback(() => setDataVersion((v) => v + 1), []);

  const value = useMemo(
    () => ({
      filters, patch, replace, clear,
      scopeSet, applySet, clearSet, backStack, goBack,
      selection, toggleSelect, setSelection, clearSelection,
      dataVersion, bumpData,
    }),
    [filters, patch, replace, clear, scopeSet, applySet, clearSet, backStack, goBack,
      selection, toggleSelect, clearSelection, dataVersion, bumpData],
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

/** 範囲の種類（URL の ?scope=）: db = 資料庫の範囲（筛选＋記録集合）、sel = 手動選択、
    rec = 記録 1 件（详情の「进入审核」「导出」から。?record=<id>）。 */
export type ScopeKind = 'db' | 'sel' | 'rec';

/** 範囲 → API に渡す条件。選択・1 件は id だけで決まる（筛选とは混ぜない）。 */
export const scopeQuery = (
  kind: ScopeKind, filters: RecordsQuery, selection: number[], recordId?: number | null,
): RecordsQuery => (
  kind === 'sel' ? { ids: selection }
    : kind === 'rec' ? { ids: recordId != null ? [recordId] : [] }
      : { ...filters });
