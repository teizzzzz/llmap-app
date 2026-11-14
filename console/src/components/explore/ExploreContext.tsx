import {
  createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode,
} from 'react';
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { ApiError, getExploreJob, startExploreBuild } from '../../api/client';
import type { ExploreJob, RecordsQuery } from '../../api/types';
import useSharedFilters, { scopeQuery } from '../../hooks/useSharedFilters';

/** 探索の範囲: 全記録 / 資料庫の筛选 / 手動選択。 */
export type ExploreScope = 'all' | 'db' | 'sel';
/** 探索区の中の画面（llmap-view の view）。主题は表紙の主题区。 */
export type ExploreView = 'explore' | 'themes' | 'chain';

interface ExploreState {
  /** /explore を表示中か。 */
  visible: boolean;
  scope: ExploreScope;
  choose: (s: ExploreScope) => void;
  job: ExploreJob | null;
  error: string | null;
  /** 生成済みバンドルの key（無ければ null）。 */
  bundleKey: string | null;
  view: ExploreView;
  goView: (v: ExploreView) => void;
  /** ExploreHost が iframe を登録する。 */
  frameRef: React.MutableRefObject<HTMLIFrameElement | null>;
}

const Ctx = createContext<ExploreState | null>(null);

/** 探索区の状態（範囲・生成ジョブ・表示中の画面）。サイドバー（操作）と
    ExploreHost（iframe）で共有する。AppLayout の内側に 1 つだけ置く。 */
export function ExploreProvider({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  const visible = pathname.startsWith('/explore');
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const shared = useSharedFilters();
  const [scope, setScope] = useState<ExploreScope>('all');
  // 範囲を確定した時点の条件（後で資料庫の筛选を変えても、探索の範囲は勝手に変えない）。
  // null = まだ決めていない（初めて表示されたときに決まる）。
  const [scopeFilters, setScopeFilters] = useState<RecordsQuery | null>(null);
  const [job, setJob] = useState<ExploreJob | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [bundleKey, setBundleKey] = useState<string | null>(null);
  const [view, setView] = useState<ExploreView>('explore');
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  // 表示されたとき: 資料庫の「探索当前筛选」等からの ?scope=db / sel を範囲として受け取る。
  // 指定が無く、まだ範囲が決まっていなければ「全部」。
  useEffect(() => {
    if (!visible) return;
    const s = params.get('scope');
    if (s === 'db' || s === 'sel') {
      setScope(s);
      setScopeFilters(scopeQuery(s, shared.filters, shared.selection));
      setParams({}, { replace: true });
    } else if (scopeFilters == null) {
      setScopeFilters({});
    }
  }, [visible, params, setParams, shared.filters, shared.selection, scopeFilters]);

  const stop = () => {
    if (timer.current != null) { clearInterval(timer.current); timer.current = null; }
  };
  useEffect(() => stop, []);

  const build = useCallback(async (filters: RecordsQuery) => {
    stop();
    setError(null);
    setJob(null);
    try {
      const { jobId } = await startExploreBuild(filters);
      const poll = async () => {
        try {
          const st = await getExploreJob(jobId);
          setJob(st);
          if (st.status === 'done') { stop(); setBundleKey(st.key || null); }
          if (st.status === 'error') { stop(); setError(st.error); }
        } catch (e: unknown) {
          stop();
          setError(e instanceof ApiError ? e.message : String(e));
        }
      };
      await poll();
      if (timer.current == null) timer.current = setInterval(poll, 800);
    } catch (e: unknown) {
      setError(e instanceof ApiError ? e.message : String(e));
    }
  }, []);

  // 表示中で範囲が決まったら生成（同じ範囲なら backend がキャッシュを即返す）。
  const builtFor = useRef<string | null>(null);
  useEffect(() => {
    if (!visible || scopeFilters == null) return;
    const sig = JSON.stringify(scopeFilters);
    if (builtFor.current === sig) return;
    builtFor.current = sig;
    void build(scopeFilters);
  }, [visible, scopeFilters, build]);

  const choose = useCallback((s: ExploreScope) => {
    setScope(s);
    setScopeFilters(s === 'all' ? {} : scopeQuery(s, shared.filters, shared.selection));
  }, [shared.filters, shared.selection]);

  const goView = useCallback((v: ExploreView) => {
    setView(v);
    frameRef.current?.contentWindow?.postMessage({ type: 'llmap:go', view: v }, '*');
  }, []);

  // 探索側からの知らせ: 画面が変わった / 「研究台で開く」。
  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      if (e.source !== frameRef.current?.contentWindow) return;
      const d = e.data as { type?: string; rid?: number; view?: string } | null;
      if (d?.type === 'llmap:openRecord' && typeof d.rid === 'number') {
        navigate(`/database?record=${d.rid}`);
      }
      if (d?.type === 'llmap:view' && (d.view === 'explore' || d.view === 'themes' || d.view === 'chain')) {
        setView(d.view);
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [navigate]);

  const value = useMemo(() => ({
    visible, scope, choose, job, error, bundleKey, view, goView, frameRef,
  }), [visible, scope, choose, job, error, bundleKey, view, goView]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export default function useExplore(): ExploreState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useExplore は ExploreProvider の内側で使う');
  return v;
}
