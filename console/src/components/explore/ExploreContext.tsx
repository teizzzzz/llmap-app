import {
  createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode,
} from 'react';
import { useTranslation } from 'react-i18next';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  ApiError, createRecordSet, getExploreJob, getExploreMeta, getRecordIds, startExploreBuild,
} from '../../api/client';
import type { ExploreDescribe, ExploreJob } from '../../api/types';
import useSharedFilters, { hasAnyFilter } from '../../hooks/useSharedFilters';
import { dbView } from '../../lib/browseMemory';
import { useRecordDrawer } from '../record/drawerContext';

// 探索の画布（照片云・色彩・主题・関係画布）を研究台の中で動かす共通の土台。
// llmap-view の複製（console/public/explore/）を 1 つの iframe として保持し、
// 各画面が置いた「枠」（slot）の上に重ねて表示する（読み直さないので位置が残る）。
//
// - データ: 全資料庫の探索データ（色・配置・縮略図）を 1 回だけ作り、範囲（資料庫の
//   筛选・記録集合）は iframe 側で「表示してよい記録」として切り替える（作り直さない）。
// - 記録の详情: 画布の写真を開くと研究台の共通の记录详情（抽屉）が開く。
// - 編集: 保存したら中身（言語・研究字段・状態）だけを取り直して差し込む。
// - 選択・開いている記録: 画布に印を描く。

/** iframe 内の画面。explore = 照片云・色彩（canvas）、themes = 主题、chain = 関係画布。 */
export type CanvasView = 'explore' | 'themes' | 'chain';
/** 画布の並べ方。wall = 照片墙、group = 照片云、wheel = 色轮、hl = 色相×明度。 */
export type CanvasMode = 'wall' | 'group' | 'wheel' | 'hl' | 'map';

/** 画布から届く現在の状態（研究台の範囲の帯に出す）。 */
export interface CanvasState {
  /** 探索内の条件まで効かせて表示している件数 */
  shown: number;
  /** 範囲内（写真のある記録） */
  inScope: number;
  /** 探索内の条件（色・言語・字段・関連・色で探す）。研究の筛选とは別。 */
  conds: { id: string; label: string; dot?: string | null }[];
  mode: CanvasMode;
  group: string;
  sort: string;
  panel: boolean;
  /** 照片云の分組（全貌で見せる組の一覧）と、いま入っている組。 */
  groups?: { v: string; label: string; n: number; sw: string | null; ph: string }[];
  focus?: string | null;
}

interface ExploreApi {
  job: ExploreJob | null;
  error: string | null;
  bundleKey: string | null;
  /** iframe が読み込まれ、メッセージを受けられる。 */
  ready: boolean;
  canvas: CanvasState | null;
  frameRef: React.MutableRefObject<HTMLIFrameElement | null>;
  slot: { el: HTMLElement; view: CanvasView } | null;
  registerSlot: (el: HTMLElement, view: CanvasView) => void;
  unregisterSlot: (el: HTMLElement) => void;
  setMode: (mode?: CanvasMode, opts?: { group?: string; sort?: string }) => void;
  /** 最後に指示した並べ方（画布の知らせが届く前でも分かる）。 */
  wantedMode: () => CanvasMode | undefined;
  setPanel: (open: boolean) => void;
  /** 組へ入る（null = 全貌へ戻る）。 */
  focusGroup: (v: string | null) => void;
  /** 画布の上に重ねる操作の置き場（各画面が portal で描く）。 */
  toolsEl: HTMLElement | null;
  setToolsEl: (el: HTMLElement | null) => void;
  fit: () => void;
  clearCond: (id: string) => void;
  chainFrom: (rid: number) => void;
  /** 範囲の切替が届いたあとで、画布の状態（条件・カメラ）を戻す。 */
  restoreLater: (snap: unknown) => void;
  describe: (rid: number) => Promise<ExploreDescribe | null>;
  activeIds: () => Promise<number[] | null>;
  snapshot: () => Promise<unknown>;
  /** 記録が変わった（详情・審核・AI の書き込み）: 全視図に読み直しを知らせ、画布の中身を
      差し替える（色・配置は作り直さない）。ids を省くと全記録。 */
  recordsChanged: (ids?: number[]) => void;
  /** 記録の増減・写真の変更の後: 探索データを作り直す（変わった写真だけ計算）。 */
  rebuild: () => void;
  /** 「返回」先の説明・画面（主题・関連へ入る前の範囲）。 */
  backHere: () => Promise<{ path: string; label: string; snapshot?: unknown }>;
}

const Ctx = createContext<ExploreApi | null>(null);

export function ExploreProvider({ children }: { children: ReactNode }) {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const shared = useSharedFilters();
  const drawer = useRecordDrawer();
  const [job, setJob] = useState<ExploreJob | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [bundleKey, setBundleKey] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const [canvas, setCanvas] = useState<CanvasState | null>(null);
  const [slot, setSlot] = useState<{ el: HTMLElement; view: CanvasView } | null>(null);
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const readyRef = useRef(false);
  readyRef.current = ready;

  const post = useCallback((msg: Record<string, unknown>) => {
    if (!readyRef.current) return;
    frameRef.current?.contentWindow?.postMessage(msg, '*');
  }, []);

  // ── 問い合わせ（iframe に計算してもらう: 详情の色・関連、表示中の id、画布の状態） ──
  const reqs = useRef(new Map<number, (v: unknown) => void>());
  const reqSeq = useRef(1);
  const request = useCallback(<T,>(what: string, args: Record<string, unknown> = {}): Promise<T | null> => {
    if (!readyRef.current) return Promise.resolve(null);
    const reqId = reqSeq.current++;
    return new Promise<T | null>((resolve) => {
      const timer = setTimeout(() => { reqs.current.delete(reqId); resolve(null); }, 4000);
      reqs.current.set(reqId, (v) => { clearTimeout(timer); resolve(v as T | null); });
      frameRef.current?.contentWindow?.postMessage({ type: 'llmap:req', reqId, what, ...args }, '*');
    });
  }, []);

  // ── 探索データ（全資料庫）を作る。起動時に 1 回（キャッシュがあれば即時）。 ──
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const pendingRestore = useRef<unknown>(null);
  const stop = () => { if (timer.current != null) { clearInterval(timer.current); timer.current = null; } };
  const build = useCallback(async (attempt = 0) => {
    stop();
    setError(null);
    try {
      const { jobId } = await startExploreBuild({});
      const poll = async () => {
        try {
          const st = await getExploreJob(jobId);
          setJob(st);
          if (st.status === 'running') return;
          stop();
          if (st.status === 'error') { setError(st.error); return; }
          const key = st.key || null;
          setBundleKey((prev) => {
            if (prev && key && prev !== key && readyRef.current) {
              // 作り直しで iframe を読み直す前に、画布の状態を取っておいて後で戻す。
              void request('snapshot').then((s) => { pendingRestore.current = s; });
            }
            return key;
          });
        } catch (e: unknown) {
          stop();
          setError(e instanceof ApiError ? e.message : String(e));
        }
      };
      await poll();
      if (timer.current == null) timer.current = setInterval(poll, 800);
    } catch (e: unknown) {
      // backend の起動待ち（桌面版）: 少し待って数回やり直す。
      if (attempt < 5) setTimeout(() => void build(attempt + 1), 3000);
      else setError(e instanceof ApiError ? e.message : String(e));
    }
  }, [request]);
  useEffect(() => { void build(); return stop; }, [build]);
  // 鍵が変われば iframe は読み直し（ready は新しい iframe の知らせを待つ）。
  useEffect(() => { setReady(false); }, [bundleKey]);

  // ── 枠（slot）: 画面が置いた場所に iframe を重ねる ──
  const registerSlot = useCallback((el: HTMLElement, view: CanvasView) => setSlot({ el, view }), []);
  const unregisterSlot = useCallback((el: HTMLElement) => setSlot((s) => (s?.el === el ? null : s)), []);
  const viewRef = useRef<CanvasView>('explore');
  useEffect(() => {
    if (!slot) return;
    viewRef.current = slot.view;
    post({ type: 'llmap:go', view: slot.view });
  }, [slot, post]);

  // ── 並べ方 ──
  const modeRef = useRef<{ mode?: CanvasMode; group?: string; sort?: string }>({});
  const setMode = useCallback((mode?: CanvasMode, opts?: { group?: string; sort?: string }) => {
    modeRef.current = { ...modeRef.current, ...(mode ? { mode } : {}), ...opts };
    post({ type: 'llmap:mode', mode, ...opts });
  }, [post]);
  const wantedMode = useCallback(() => modeRef.current.mode, []);
  const setPanel = useCallback((open: boolean) => post({ type: 'llmap:panel', open }), [post]);
  const fit = useCallback(() => post({ type: 'llmap:fit' }), [post]);
  const focusGroup = useCallback((v: string | null) => post({ type: 'llmap:focusGroup', v }), [post]);
  const [toolsEl, setToolsEl] = useState<HTMLElement | null>(null);
  const clearCond = useCallback((id: string) => post({ type: 'llmap:clearCond', id }), [post]);
  const chainFrom = useCallback((rid: number) => {
    // 画面（関係画布）の枠が付くより先に届いても、iframe 側で chain へ切り替えて始める。
    if (readyRef.current) post({ type: 'llmap:chainFrom', rid });
    else pendingChain.current = rid;
  }, [post]);
  const pendingChain = useRef<number | null>(null);

  // ── 範囲（資料庫の筛选＋記録集合）→ 画布に表示してよい記録 ──
  const filters = shared.filters;
  const sig = JSON.stringify(filters);
  const lastSig = useRef<string | null>(null);
  const flushRestore = useCallback(() => {
    if (pendingRestore.current != null) {
      post({ type: 'llmap:restore', snap: pendingRestore.current });
      pendingRestore.current = null;
    }
  }, [post]);
  useEffect(() => {
    if (!ready) return;
    let stale = false;
    const same = lastSig.current === sig;
    const ids = hasAnyFilter(filters)
      ? getRecordIds(filters).then((r) => r.ids)
      : Promise.resolve(null);
    ids.then((rids) => {
      if (stale) return;
      lastSig.current = sig;
      // 同じ範囲で中身だけ変わった（編集）ならカメラはそのまま。
      post({ type: 'llmap:scope', rids, keepCamera: same });
      flushRestore();
    }).catch(() => { /* 範囲が取れなければ前の表示のまま */ });
    return () => { stale = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, sig, shared.dataVersion, post, flushRestore]);
  const restoreLater = useCallback((snap: unknown) => {
    pendingRestore.current = snap;
    // 範囲が変わらない場合はすぐ戻す（範囲の切替が届けば、その後で戻る）。
    setTimeout(() => { if (readyRef.current) flushRestore(); }, 250);
  }, [flushRestore]);

  useEffect(() => { post({ type: 'llmap:selection', rids: shared.selection }); }, [ready, shared.selection, post]);
  useEffect(() => { post({ type: 'llmap:focus', rid: drawer.current }); }, [ready, drawer.current, post]);
  const lang = i18n.language.startsWith('ja') ? 'ja' : 'zh';
  useEffect(() => { post({ type: 'llmap:lang', lang }); }, [ready, lang, post]);

  const describe = useCallback((rid: number) => request<ExploreDescribe>('describe', { rid }), [request]);
  const activeIds = useCallback(() => request<number[]>('active'), [request]);
  const snapshot = useCallback(() => request<unknown>('snapshot'), [request]);
  const { bumpData } = shared;
  const recordsChanged = useCallback((ids?: number[]) => {
    bumpData();
    if (!readyRef.current) return;
    // 中身だけを取り直して差し込む（数が多ければ分けて）。失敗しても次の読み込みで最新になる。
    (ids ? Promise.resolve(ids) : getRecordIds({}).then((r) => r.ids))
      .then(async (all) => {
        for (let k = 0; k < all.length; k += 800) {
          const r = await getExploreMeta(all.slice(k, k + 800));
          post({ type: 'llmap:patch', records: r.records });
        }
      })
      .catch(() => { /* data.js は毎回 DB から作るので、読み直せば最新 */ });
  }, [bumpData, post]);
  const rebuild = useCallback(() => { void build(); }, [build]);

  const backHere = useCallback(async () => {
    const path = pathname === '/database' ? `/database?view=${dbView.current || 'album'}` : pathname;
    const label = shared.scopeSet?.label
      ?? (hasAnyFilter(shared.filters) ? t('scope.backFiltered') : t('scope.backAll'));
    const onCanvas = pathname === '/database' ? dbView.current === 'cloud' : pathname === '/canvas';
    const snap = onCanvas ? await snapshot() : undefined;
    return { path, label, snapshot: snap ?? undefined };
  }, [pathname, shared.scopeSet, shared.filters, snapshot, t]);

  // ── iframe からの知らせ ──
  const slotRef = useRef(slot);
  slotRef.current = slot;
  const sharedRef = useRef(shared);
  sharedRef.current = shared;
  const backHereRef = useRef(backHere);
  backHereRef.current = backHere;
  useEffect(() => {
    const onMsg = async (e: MessageEvent) => {
      if (e.source !== frameRef.current?.contentWindow) return;
      const d = e.data as Record<string, unknown> | null;
      if (!d || typeof d.type !== 'string') return;
      if (d.type === 'llmap:ready') {
        setReady(true);
        readyRef.current = true;
        lastSig.current = null; // 新しい iframe には範囲を送り直す
        const w = frameRef.current?.contentWindow;
        w?.postMessage({ type: 'llmap:go', view: viewRef.current }, '*');
        if (modeRef.current.mode || modeRef.current.group) w?.postMessage({ type: 'llmap:mode', ...modeRef.current }, '*');
        if (pendingChain.current != null) {
          w?.postMessage({ type: 'llmap:chainFrom', rid: pendingChain.current }, '*');
          pendingChain.current = null;
        }
      } else if (d.type === 'llmap:wheel' && typeof d.dy === 'number') {
        // 首页の主题の上でホイール: ページ（.content）を動かす。
        slotRef.current?.el.closest('.content')?.scrollBy({ top: d.dy });
      } else if (d.type === 'llmap:state') {
        setCanvas(d as unknown as CanvasState);
      } else if (d.type === 'llmap:open' && typeof d.rid === 'number') {
        drawer.open(d.rid);
      } else if (d.type === 'llmap:reply' && typeof d.reqId === 'number') {
        reqs.current.get(d.reqId)?.(d.data);
        reqs.current.delete(d.reqId);
      } else if (d.type === 'llmap:theme' && Array.isArray(d.rids)) {
        // 主题＝一組の記録への入口。記録集合として資料庫の範囲にし、条件と件数を示す。
        try {
          const back = await backHereRef.current();
          const { key, count } = await createRecordSet(d.rids as number[]);
          sharedRef.current.applySet({
            key, count, origin: 'theme',
            label: t('scope.themeLabel', { title: String(d.title ?? '') }),
            conds: (d.conds as string[]) ?? [],
          }, { back });
          modeRef.current = { mode: (d.mode as CanvasMode) || 'group', group: String(d.group || 'cn') };
          frameRef.current?.contentWindow?.postMessage({ type: 'llmap:mode', ...modeRef.current }, '*');
          navigate('/database?view=cloud');
        } catch (err: unknown) {
          setError(err instanceof ApiError ? err.message : String(err));
        }
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [drawer, navigate, t]);

  const value = useMemo<ExploreApi>(() => ({
    job, error, bundleKey, ready, canvas, frameRef, slot, registerSlot, unregisterSlot,
    setMode, wantedMode, setPanel, focusGroup, toolsEl, setToolsEl, fit, clearCond, chainFrom, restoreLater,
    describe, activeIds, snapshot, recordsChanged, rebuild, backHere,
  }), [job, error, bundleKey, ready, canvas, slot, registerSlot, unregisterSlot, setMode, wantedMode, setPanel, focusGroup, toolsEl,
    fit, clearCond, chainFrom, restoreLater, describe, activeIds, snapshot, recordsChanged, rebuild, backHere]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export default function useExplore(): ExploreApi {
  const v = useContext(Ctx);
  if (!v) throw new Error('useExplore は ExploreProvider の内側で使う');
  return v;
}

/** 画面に画布の枠を置く（ref に渡す）。枠が表示されている間、iframe がその上に重なる。 */
export function useCanvasSlot(view: CanvasView) {
  const ex = useExplore();
  const { registerSlot, unregisterSlot } = ex;
  const elRef = useRef<HTMLElement | null>(null);
  const ref = useCallback((el: HTMLElement | null) => {
    if (elRef.current && elRef.current !== el) unregisterSlot(elRef.current);
    elRef.current = el;
    if (el) registerSlot(el, view);
  }, [registerSlot, unregisterSlot, view]);
  return ref;
}
