import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { createPortal } from 'react-dom';
import { API_BASE_URL, ApiError, createRecordSet, getRecords } from '../api/client';
import type { RecordsQuery, RecordsResponse } from '../api/types';
import MenuButton from '../components/MenuButton';
import ImportDatasetDialog from '../components/database/ImportDatasetDialog';
import RecordsFilters from '../components/database/RecordsFilters';
import RecordsMap from '../components/database/RecordsMap';
import RecordsMasonry, { ThumbSlider, useThumbSize } from '../components/database/RecordsMasonry';
import RecordsTable from '../components/database/RecordsTable';
import useExplore, { useCanvasSlot, type CanvasMode } from '../components/explore/ExploreContext';
import { useRecordDrawer } from '../components/record/drawerContext';
import { browseState, dbView, saveBrowse } from '../lib/browseMemory';
import useAiEnabled from '../hooks/useAiEnabled';
import useFilterOptions from '../hooks/useFilterOptions';
import useSharedFilters, { hasAnyFilter } from '../hooks/useSharedFilters';
import { languageFilterValues } from '../lib/languageList';

const PAGE_SIZE = 50;
const VIEW_KEY = 'llmap.dbView';
const MODES_KEY = 'llmap.canvasModes';

/** 同じ資料庫（同じ範囲）の見方。照片・表格・地図は研究の一覧、照片云は探索の画布。 */
export type DbView = 'album' | 'table' | 'map' | 'cloud';
const VIEWS: DbView[] = ['album', 'table', 'map', 'cloud'];
const isCanvas = (v: DbView) => v === 'cloud';
const asView = (v: string | null): DbView | null => (VIEWS.includes(v as DbView) ? (v as DbView) : null);

// 照片云の分組（探索の DIMS と同じ鍵）。'' = 分けない（照片墙）。
const GROUPS = ['', 'cn', 'lang', 'rel', 'dis', 'car', 'pos', 'tmp', 'q', 'day'];
const SORTS = ['spec', 'light', 'cf', 'time', 'lang'];

const loadModes = (): { cloud: string; group: string; sort: string; color: CanvasMode } => {
  try {
    return { cloud: 'group', group: 'cn', sort: 'spec', color: 'wheel', ...JSON.parse(localStorage.getItem(MODES_KEY) || '{}') };
  } catch { return { cloud: 'group', group: 'cn', sort: 'spec', color: 'wheel' }; }
};

/** 資料庫（既定の入口）。同じ範囲を 照片｜表格｜地図｜照片云｜色彩 で見る。
    範囲（研究の筛选・記録集合）と手動選択はどの視図でも共通で、審核・AI・導出へも引き継ぐ。
    記録はどの視図からでも同じ详情（右の抽屉）で開く。 */
export default function DatabasePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const shared = useSharedFilters();
  const {
    filters, patch, replace, clear,
    selection, toggleSelect, setSelection, clearSelection, dataVersion,
  } = shared;
  const ex = useExplore();
  const drawer = useRecordDrawer();
  const [aiOn] = useAiEnabled();
  const [data, setData] = useState<RecordsResponse | null>(null);
  const [albumTotal, setAlbumTotal] = useState<number | null>(null);
  const [mapCount, setMapCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [importing, setImporting] = useState(false);
  const [busy, setBusy] = useState(false);
  const [searchParams, setSearchParams] = useSearchParams();
  // 視図: ?view= があればそれ、無ければ前回の選択（初回は写真）。
  const [view, setViewState] = useState<DbView>(() => {
    const fromUrl = asView(searchParams.get('view'));
    if (fromUrl) return fromUrl;
    try { return asView(localStorage.getItem(VIEW_KEY)) ?? 'album'; } catch { return 'album'; }
  });
  useEffect(() => {
    dbView.current = view;
    try { localStorage.setItem(VIEW_KEY, view); } catch { /* 保存できなくても表示は切替わる */ }
  }, [view]);

  // 閲覧状態（審核・主题・関係画布などへ行って戻ったとき、続きから）。
  // 鍵＝範囲＋視図。同じ範囲ならページ・読込済み枚数・スクロール位置を戻す。
  const browseKey = JSON.stringify(filters) + '|' + view;
  const [page, setPage] = useState(() => browseState(browseKey)?.tablePage ?? 1);
  const browseRef = useRef({ key: browseKey, page });
  browseRef.current = { key: browseKey, page };
  useEffect(() => {
    if (isCanvas(view) || view === 'map') return undefined;
    const content = () => document.querySelector<HTMLElement>('.content');
    const target = browseState(browseKey)?.scroll ?? 0;
    // 離れる時点の .content は次のページに替わっているので、位置は随時記録しておく。
    let last = target;
    const el0 = content();
    const onScroll = () => { last = el0?.scrollTop ?? 0; };
    el0?.addEventListener('scroll', onScroll, { passive: true });
    let raf = 0;
    if (target > 0) {
      // 写真・行が読み込まれ、配置が落ち着いて（高さが数フレーム変わらない）から戻す。
      const until = performance.now() + 4000;
      let prevH = -1;
      let steady = 0;
      const tick = () => {
        const el = content();
        if (!el) return;
        const h = el.scrollHeight;
        steady = h === prevH ? steady + 1 : 0;
        prevH = h;
        if ((h - el.clientHeight >= target && steady >= 8) || performance.now() > until) {
          el.scrollTop = target;
          last = el.scrollTop;
        } else {
          raf = requestAnimationFrame(tick);
        }
      };
      raf = requestAnimationFrame(tick);
    } else if (el0) {
      el0.scrollTop = 0;
    }
    const key = browseKey;
    return () => {
      cancelAnimationFrame(raf);
      el0?.removeEventListener('scroll', onScroll);
      saveBrowse(key, { tablePage: browseRef.current.page, scroll: last });
    };
    // 範囲・視図が変わるたびに（前のものを保存し、新しいものを戻す）。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [browseKey]);
  useEffect(() => { setPage(browseState(browseKey)?.tablePage ?? 1); }, [browseKey]);
  const [thumb, setThumb] = useThumbSize();

  const { schema, datasets, areas, collectors, fieldStats,
    refresh: fetchOptions } = useFilterOptions();

  // 旧来の深いリンク: ?record=<id> は详情で開く。?view= は視図。
  useEffect(() => {
    const rid = searchParams.get('record');
    const v = asView(searchParams.get('view'));
    if (v) setViewState(v);
    if (rid) drawer.open(Number(rid));
    if (rid || searchParams.get('view')) setSearchParams({}, { replace: true });
  }, [searchParams, setSearchParams, drawer]);

  const fetchRecords = useCallback(() => {
    if (view !== 'table') return;
    setLoading(true);
    setError(null);
    getRecords({ ...filters, page, pageSize: PAGE_SIZE })
      .then(setData)
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters, page, view, dataVersion]);
  useEffect(fetchRecords, [fetchRecords]);

  // 範囲全体の件数（写真の有無を問わない）と、そのうち写真の無い件数。
  const [scopeTotal, setScopeTotal] = useState<number | null>(null);
  const [noPhoto, setNoPhoto] = useState<number | null>(null);
  useEffect(() => {
    let stale = false;
    getRecords({ ...filters, page: 1, pageSize: 1 })
      .then((r) => { if (!stale) setScopeTotal(r.total); })
      .catch(() => { if (!stale) setScopeTotal(null); });
    if (filters.hasPhoto === undefined) {
      getRecords({ ...filters, hasPhoto: false, page: 1, pageSize: 1 })
        .then((r) => { if (!stale) setNoPhoto(r.total); })
        .catch(() => { if (!stale) setNoPhoto(null); });
    } else {
      setNoPhoto(null);
    }
    return () => { stale = true; };
  }, [filters, dataVersion]);

  // 筛选変更は必ず 1 ページ目へ戻す。
  const patchFilters = useCallback((p: Partial<RecordsQuery>) => {
    patch(p);
    setPage(1);
  }, [patch]);

  // ── 画布（照片云・色彩） ──
  const slotRef = useCanvasSlot('explore');
  const [modes, setModes] = useState(loadModes);
  const saveModes = (m: Partial<ReturnType<typeof loadModes>>) => setModes((prev) => {
    const next = { ...prev, ...m };
    try { localStorage.setItem(MODES_KEY, JSON.stringify(next)); } catch { /* */ }
    return next;
  });
  // 視図に入ったら並べ方を合わせる（主题から来たときは主题の分組を優先）。
  useEffect(() => {
    if (!isCanvas(view)) return;
    // 指示済み（主题から来た等）ならそれを、まだ無ければ前回の並べ方（初回は分組）。
    const cur = ex.wantedMode();
    if (view === 'cloud' && cur !== 'group' && cur !== 'wall') {
      ex.setMode(modes.cloud as CanvasMode, { group: modes.group, sort: modes.sort });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [view, ex.ready]);
  const [canvasFull, setCanvasFull] = useState(false);
  useEffect(() => {
    if (!isCanvas(view)) { setCanvasFull(false); return undefined; }
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      if (e.key === 'Escape' && !document.querySelector('.drawer, .lightbox-overlay, .modal-overlay')) setCanvasFull(false);
      if (e.key.toLowerCase() === 'f') setCanvasFull((v) => !v);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [view]);
  useEffect(() => {
    document.body.classList.toggle('canvas-full', canvasFull);
    return () => document.body.classList.remove('canvas-full');
  }, [canvasFull]);

  const conds = isCanvas(view) ? ex.canvas?.conds ?? [] : [];

  /** 探索内の条件（色・言語・関連など）は研究の筛选にできない。表示中の記録を
      「記録集合」として範囲にし（条件は名前として残す）、画布の条件は外す。 */
  const materialize = async (): Promise<boolean> => {
    if (!conds.length) return true;
    setBusy(true);
    try {
      const rids = await ex.activeIds();
      if (!rids) return false;
      const back = await ex.backHere();
      const { key, count } = await createRecordSet(rids);
      const prev = shared.scopeSet;
      shared.applySet({
        key, count, origin: 'explore',
        label: prev ? prev.label : t('scope.exploreLabel'),
        conds: [...(prev ? prev.conds : []), ...conds.map((c) => c.label)],
      }, { keepFilters: true, back });
      ex.clearCond('*');
      return true;
    } catch {
      return false;
    } finally {
      setBusy(false);
    }
  };

  const switchView = async (v: DbView) => {
    if (v === view) return;
    // 画布の条件は、研究の一覧（照片・表格・地図）でも同じ記録を見られるよう記録集合にする。
    if (isCanvas(view) && !isCanvas(v) && conds.length && !(await materialize())) return;
    setViewState(v);
  };

  /** 範囲を次の作業へ（画布の条件があれば先に記録集合にする —— 黙って落とさない）。 */
  const sendScope = async (path: string) => {
    if (conds.length && !(await materialize())) return;
    navigate(path);
  };

  /** 導入直後: 今回の導入分（データセット）だけに絞って写真で見る。 */
  const viewImported = (datasetId: number, then?: 'review' | 'ai') => {
    replace({ datasetIds: [datasetId] });
    setPage(1);
    setViewState('album');
    setImporting(false);
    // 範囲＝本次导入分のまま、審核 / AI へ（?scope=db で引き継ぐ）。
    if (then) navigate(`/${then}?scope=db`);
  };

  /** 選んだ記録だけを範囲にする（記録集合。「返回」で前の範囲へ）。 */
  const onlySelected = async () => {
    setBusy(true);
    try {
      const back = await ex.backHere();
      const { key, count } = await createRecordSet(selection);
      shared.applySet({ key, count, origin: 'selection', label: t('scope.selectionLabel', { n: count }), conds: [] }, { back });
    } finally {
      setBusy(false);
    }
  };

  const onBack = () => {
    const e = shared.goBack();
    if (!e) return;
    if (e.snapshot) ex.restoreLater(e.snapshot);
    navigate(e.path);
  };

  const lastPage = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  // 批量操作の対象: 画布の条件があれば画布に出ている件数、無ければ範囲の件数。
  const n = conds.length ? ex.canvas?.shown ?? 0 : scopeTotal ?? 0;

  // 件数は見出しの 1 か所だけ（視図ごとに「何の数か」を添える）。
  const headCount = (() => {
    if (view === 'table') return t('database.countTable', { n: data?.total ?? '—' });
    if (view === 'album') return t('database.countAlbum', { n: albumTotal ?? '—' });
    if (view === 'map') return t('database.countMap', { n: mapCount ?? '—', total: scopeTotal ?? '—' });
    const c = ex.canvas;
    return c ? t('database.countCanvas', { shown: c.shown, n: c.inScope }) : '';
  })();

  const set = shared.scopeSet;
  const back = shared.backStack[shared.backStack.length - 1];
  const hasExtra = !!set || !!back || conds.length > 0;
  /** 「全部清除」: 研究の筛选・記録集合・画布の条件をまとめて外す（選択は別）。 */
  const clearAll = () => {
    clear();
    if (set) shared.clearSet();
    if (conds.length) ex.clearCond('*');
    setPage(1);
  };

  return (
    <div className={`db-page${isCanvas(view) ? ' canvas-mode' : ''}`}>
      {/* 1 段目（ページ）: 名前・件数・導入・批量操作 */}
      <div className="page-head compact db-head">
        <h1>{t('database.title')}<span key={headCount} className="page-count small">{headCount}</span></h1>
        <div className="page-actions">
          {view === 'album' && <ThumbSlider value={thumb} onChange={setThumb} />}
          <button className="btn" onClick={() => setImporting(true)}>{t('database.import')}</button>
          {/* 範囲（結果すべて）に対する操作。各項目に対象と件数を明記する。 */}
          <MenuButton className="btn primary" label={t('database.bulkMenu')}>
            {(close) => (
              <>
                <div className="menu-note">{t('database.bulkTarget', { n })}</div>
                <button type="button" role="menuitem" className="menu-item" disabled={!n || busy}
                  onClick={() => { close(); void sendScope('/review?scope=db'); }}>
                  {t('database.scopeReview', { n })}
                </button>
                {aiOn && (
                  <button type="button" role="menuitem" className="menu-item" disabled={!n || busy}
                    onClick={() => { close(); void sendScope('/ai?scope=db'); }}>
                    {t('database.scopeAi', { n })}
                  </button>
                )}
                <button type="button" role="menuitem" className="menu-item" disabled={!n || busy}
                  onClick={() => { close(); void sendScope('/export?scope=db'); }}>
                  {t('database.scopeExport', { n })}
                </button>
              </>
            )}
          </MenuButton>
        </div>
      </div>

      {importing && (
        <ImportDatasetDialog
          onClose={() => setImporting(false)}
          onImported={() => { ex.recordsChanged(); fetchOptions(); ex.rebuild(); }}
          onViewImported={viewImported}
          aiOn={aiOn}
        />
      )}

      {/* 2 段目（見方）: 視図・検索・常用の筛选・更多。適用中の条件は、あるときだけ下に 1 行。 */}
      <RecordsFilters
        value={filters}
        options={{
          languages: languageFilterValues(schema?.enums['主要言語']),
          areas, collectors, datasets,
        }}
        schemaEnums={schema?.enums}
        fieldPresence={fieldStats}
        total={null}
        hideCount
        onChange={patchFilters}
        onClear={clearAll}
        leading={(
          <div className="seg db-views" role="tablist" aria-label={t('database.view')}>
            {VIEWS.map((v) => (
              <button key={v} type="button" role="tab" aria-selected={view === v}
                className={view === v ? 'on' : ''} disabled={busy} onClick={() => void switchView(v)}>
                {t(`database.views.${v}`)}
              </button>
            ))}
          </div>
        )}
        hasExtra={hasExtra}
        extraChips={(
          <>
            {back && (
              <button type="button" className="chip back-chip" disabled={busy} onClick={onBack}
                title={t('scope.backTitle')}>
                ← {t('scope.back', { label: back.label })}
              </button>
            )}
            {set && (
              <button type="button" className="chip removable set-chip" onClick={shared.clearSet}
                title={t('scope.removeSet')}>
                {(set.origin === 'theme' || set.origin === 'relation') && (
                  <small>{t(`scope.origin.${set.origin}`)}</small>
                )}
                {[set.label, ...set.conds].join(' · ')}
                <span aria-hidden="true">×</span>
              </button>
            )}
            {conds.map((c) => (
              <button key={c.id} type="button" className="chip removable" onClick={() => ex.clearCond(c.id)}>
                {c.dot && <i className="sw" style={{ background: c.dot }} />}
                {c.label}<span aria-hidden="true">×</span>
              </button>
            ))}
          </>
        )}
      />

      {/* 相册・画布は写真のある記録だけ。写真の無い記録の件数と見る方法を明示する。 */}
      {(view === 'album' || isCanvas(view)) && (noPhoto ?? 0) > 0 && (
        <div className="note-line">
          {t(view === 'album' ? 'database.albumNoPhotoNote' : 'database.canvasNoPhotoNote',
            { shown: albumTotal ?? '—', missing: noPhoto })}
          <button type="button" className="link-btn"
            onClick={() => { patchFilters({ hasPhoto: false }); setViewState('table'); }}>
            {t('database.showNoPhoto')}
          </button>
        </div>
      )}

      {view === 'album' && (
        <RecordsMasonry filters={filters} thumb={thumb} onThumb={setThumb} onTotal={setAlbumTotal}
          restoreKey={browseKey}
          onOpen={(r) => drawer.open(r.id)} selectedId={drawer.current} reloadKey={dataVersion}
          checked={selection} onToggleCheck={toggleSelect} />
      )}

      {view === 'table' && (
        <div className="table-wrap">
          {error && (
            <div className="error-box">
              <strong>{t('database.loadError')}</strong>
              <div className="hint">{error}</div>
            </div>
          )}
          {!error && loading && !data && <div className="muted">{t('database.loading')}</div>}
          {!error && !loading && data && data.items.length === 0 && (
            <div className="placeholder">
              <p>{hasAnyFilter(filters)
                ? t('database.noMatch')
                : t('database.empty', { button: t('database.import') })}</p>
            </div>
          )}
          {!error && data && data.items.length > 0 && (
            <>
              <RecordsTable items={data.items} selectedId={drawer.current} onSelect={(id) => id != null && drawer.open(id)}
                checked={selection} onToggleCheck={toggleSelect}
                onToggleAll={(ids, on) => setSelection(on
                  ? [...selection, ...ids.filter((id) => !selection.includes(id))]
                  : selection.filter((id) => !ids.includes(id)))} />
              {lastPage > 1 && (
                <div className="pagination">
                  <button className="btn ghost" disabled={page <= 1} onClick={() => setPage(page - 1)}>←</button>
                  <span className="mono">{page} / {lastPage}</span>
                  <button className="btn ghost" disabled={page >= lastPage} onClick={() => setPage(page + 1)}>→</button>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {view === 'map' && (
        <RecordsMap query={filters} version={dataVersion} onOpen={(id) => drawer.open(id)}
          onCount={setMapCount} openId={drawer.current} />
      )}

      {isCanvas(view) && (
        <div className={`canvas-area${canvasFull ? ' is-full' : ''}`}>
          <div className="canvas-slot" ref={slotRef} />
        </div>
      )}
      {/* 画布の操作は画布の上に（分組・筛选面板・全画面、下に「全貌」と組の一覧）。 */}
      {isCanvas(view) && ex.toolsEl && createPortal((
        <>
          <div className="ct-top">
            <label className="mini-field">
              <span>{t('canvas.group')}</span>
              <select value={ex.canvas?.mode === 'wall' ? '' : ex.canvas?.group ?? modes.group}
                onChange={(e) => {
                  const g = e.target.value;
                  if (g) { ex.setMode('group', { group: g }); saveModes({ cloud: 'group', group: g }); }
                  else { ex.setMode('wall'); saveModes({ cloud: 'wall' }); }
                }}>
                {GROUPS.map((g) => <option key={g || 'none'} value={g}>{t(`canvas.groups.${g || 'none'}`)}</option>)}
              </select>
            </label>
            {ex.canvas?.mode === 'wall' && (
              <label className="mini-field">
                <span>{t('canvas.sort')}</span>
                <select value={ex.canvas?.sort ?? modes.sort}
                  onChange={(e) => { ex.setMode(undefined, { sort: e.target.value }); saveModes({ sort: e.target.value }); }}>
                  {SORTS.map((s2) => <option key={s2} value={s2}>{t(`canvas.sorts.${s2}`)}</option>)}
                </select>
              </label>
            )}
            <span className="spacer" />
            <button type="button" className={`btn sm${ex.canvas?.panel ? ' on' : ''}`} aria-pressed={!!ex.canvas?.panel}
              disabled={!ex.ready} onClick={() => ex.setPanel(!ex.canvas?.panel)}>
              {t('canvas.panel')}
            </button>
            <button type="button" className="btn sm" onClick={() => setCanvasFull((v) => !v)}>
              {canvasFull ? t('canvas.exitFull') : t('canvas.full')}<kbd>{canvasFull ? 'Esc' : 'F'}</kbd>
            </button>
          </div>
          {ex.canvas?.mode === 'group' && (ex.canvas.groups?.length ?? 0) > 1 && (
            <div className="ct-groups" role="toolbar" aria-label={t('canvas.groupsLabel')}>
              <button type="button" className={`ct-group overview${ex.canvas.focus == null ? ' on' : ''}`}
                onClick={ex.fit}>
                {t('canvas.overview')}
              </button>
              {ex.canvas.groups!.map((g) => (
                <button key={g.v} type="button" className={`ct-group${ex.canvas!.focus === g.v ? ' on' : ''}`}
                  onClick={() => ex.focusGroup(ex.canvas!.focus === g.v ? null : g.v)}
                  title={t('canvas.enterGroup', { name: g.label })}>
                  <img src={`${API_BASE_URL}/thumbs/${encodeURIComponent(g.ph)}`} alt="" />
                  {g.sw && <i className="sw" style={{ background: g.sw }} />}
                  <span className="ct-group-l">{g.label}</span>
                  <span className="ct-group-n">{g.n}</span>
                </button>
              ))}
            </div>
          )}
        </>
      ), ex.toolsEl)}

      {/* 手動選択の操作帯: 範囲（上のメニュー）とは別に、選んだ記録だけに効く。 */}
      {selection.length > 0 && (
        <div className="select-bar" role="region" aria-label={t('database.selectionBar')}>
          <span className="select-n">{t('database.selectedCount', { n: selection.length })}</span>
          <button type="button" className="btn ghost" onClick={clearSelection}>
            {t('database.clearSelection')}
          </button>
          <button type="button" className="btn ghost" disabled={busy} onClick={() => void onlySelected()}>
            {t('database.selOnly', { n: selection.length })}
          </button>
          <span className="spacer" />
          <button type="button" className="btn" onClick={() => navigate('/review?scope=sel')}>
            {t('database.selReview', { n: selection.length })}
          </button>
          {aiOn && (
            <button type="button" className="btn" onClick={() => navigate('/ai?scope=sel')}>
              {t('database.selAi', { n: selection.length })}
            </button>
          )}
          <button type="button" className="btn primary" onClick={() => navigate('/export?scope=sel')}>
            {t('database.selExport', { n: selection.length })}
          </button>
        </div>
      )}
    </div>
  );
}
