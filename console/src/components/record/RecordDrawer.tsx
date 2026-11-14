import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useLocation, useNavigate } from 'react-router-dom';
import { API_BASE_URL, createRecordSet, getRecords, getSchema } from '../../api/client';
import type { ExploreDescribe, RecordDetail, SchemaInfo } from '../../api/types';
import useAiEnabled from '../../hooks/useAiEnabled';
import useSharedFilters, { hasAnyFilter } from '../../hooks/useSharedFilters';
import { dbView } from '../../lib/browseMemory';
import MenuButton from '../MenuButton';
import RecordDetailPanel from '../database/RecordDetailPanel';
import useExplore from '../explore/ExploreContext';
import { useRecordDrawer } from './drawerContext';

let schemaCache: SchemaInfo | null = null;

/** 共通の記録详情（抽屉）。どの視図から開いても同じ。AppLayout に 1 つだけ置く。
    並び: 写真 → 言語と地点 → 主な操作（编辑字段・选中）→ 字段／関連。
    低頻度の操作（审核・导出・AI・関係画布）は「更多」へ。 */
export default function RecordDrawer() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const drawer = useRecordDrawer();
  const shared = useSharedFilters();
  const ex = useExplore();
  const [aiOn] = useAiEnabled();
  const [schema, setSchema] = useState<SchemaInfo | null>(schemaCache);
  const [outOfScope, setOutOfScope] = useState(false);
  const rid = drawer.current;

  useEffect(() => {
    if (!schemaCache) getSchema().then((s) => { schemaCache = s; setSchema(s); }).catch(() => {});
  }, []);
  useEffect(() => setOutOfScope(false), [rid]);
  // 详情は資料を見る画面（資料庫・関係画布）のもの。設定・導出などへ移ったら閉じる
  // （未保存があれば確認）。
  const { pathname } = useLocation();
  useEffect(() => {
    if (!['/database', '/canvas'].includes(pathname)) void drawer.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // Esc で閉じる（写真ビューア・ダイアログ・メニュー表示中はそちらに譲る）。
  useEffect(() => {
    if (rid == null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape' || document.querySelector('.lightbox-overlay, .modal-overlay, .menu-pop')) return;
      void drawer.close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [rid, drawer]);

  const onSaved = useCallback((d: RecordDetail) => {
    ex.recordsChanged([d.id]);
    // 編集で今の範囲に合わなくなったら知らせる（一覧からは消えるが、详情は開いたまま）。
    if (hasAnyFilter(shared.filters)) {
      getRecords({ ...shared.filters, ids: [d.id], page: 1, pageSize: 1 })
        .then((r) => setOutOfScope(r.total === 0))
        .catch(() => {});
    }
  }, [shared.filters, ex]);

  if (rid == null) return null;
  const selected = shared.selection.includes(rid);
  const go = async (path: string) => { if (await drawer.close()) navigate(path); };

  return (
    <div className="drawer" role="dialog" aria-label={t('record.detail')}>
      <RecordDetailPanel
        recordId={rid}
        schema={schema}
        onSaved={onSaved}
        onClose={() => void drawer.close()}
        notice={outOfScope && (
          <div className="dp-notice" role="status">{t('record.outOfScope')}</div>
        )}
        actions={(
          <>
            <button type="button" className={`btn sm${selected ? ' on' : ''}`} aria-pressed={selected}
              onClick={() => shared.toggleSelect(rid)}>
              {selected ? t('record.selected') : t('record.select')}
            </button>
            <span className="spacer" />
            <MenuButton className="btn sm ghost" label={t('record.more')}>
              {(close) => (
                <>
                  <button type="button" role="menuitem" className="menu-item"
                    onClick={() => { close(); void go(`/review?scope=rec&record=${rid}`); }}>
                    {t('record.toReview')}
                  </button>
                  <button type="button" role="menuitem" className="menu-item"
                    onClick={() => { close(); void go(`/export?scope=rec&record=${rid}`); }}>
                    {t('record.export')}
                  </button>
                  {aiOn && (
                    <button type="button" role="menuitem" className="menu-item"
                      onClick={() => { close(); void go(`/ai?scope=rec&record=${rid}`); }}>
                      {t('record.ai')}
                    </button>
                  )}
                  <button type="button" role="menuitem" className="menu-item" disabled={!ex.ready}
                    onClick={() => { close(); ex.chainFrom(rid); navigate('/canvas'); }}>
                    {t('record.continueRelations')}
                  </button>
                </>
              )}
            </MenuButton>
          </>
        )}
        explore={<ExploreFacet rid={rid} />}
      />
    </div>
  );
}

/** 详情の「探索」区: 色板・色の情報・6 種の関連。関連は全資料庫から探す ——
    いまの範囲が資料庫の一部なら「範囲内 M／全部 N」と示し、どちらで見るかを選べる。
    開くとその記録の集まりを範囲にして資料庫で見る（「返回」で元の範囲・位置へ）。 */
function ExploreFacet({ rid }: { rid: number }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const ex = useExplore();
  const shared = useSharedFilters();
  const drawer = useRecordDrawer();
  const [info, setInfo] = useState<ExploreDescribe | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const filtersSig = JSON.stringify(shared.filters);

  useEffect(() => {
    let stale = false;
    setInfo(undefined);
    if (!ex.ready) return;
    // 範囲の切替が画布に届いてから数える（少し待つ）。
    const timer = setTimeout(() => {
      ex.describe(rid).then((d) => { if (!stale) setInfo(d); });
    }, 300);
    return () => { stale = true; clearTimeout(timer); };
    // 編集（dataVersion）・範囲で関連・範囲内の数が変わるので取り直す。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rid, ex.ready, shared.dataVersion, filtersSig]);

  if (!ex.ready) {
    const j = ex.job;
    return (
      <p className="muted dp-ex-wait">
        {ex.error ? t('explore.failed')
          : j?.status === 'running' ? t(`explore.phase.${j.phase}`, { done: j.done, total: j.total })
            : t('explore.loading')}
      </p>
    );
  }
  if (info === undefined) return <p className="muted dp-ex-wait">{t('explore.loading')}</p>;
  if (info === null) return <p className="muted dp-ex-wait">{t('record.noExplore')}</p>;

  const openRelation = async (rel: ExploreDescribe['relations'][number], within: boolean) => {
    setBusy(true);
    try {
      const back = await ex.backHere();
      const ids = within ? [rid, ...rel.inScope] : rel.rids;
      const { key, count } = await createRecordSet(ids);
      shared.applySet({
        key, count, origin: 'relation',
        label: t('scope.relationLabel', { name: rel.name }),
        conds: [rel.title, within ? t('record.relWithin') : t('record.relWhole')],
      }, { back });
      const v = ['cloud', 'album', 'table', 'map'].includes(dbView.current) ? dbView.current : 'cloud';
      navigate(`/database?view=${v}`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="dp-ex">
      <div className="dp-pal" aria-hidden="true">
        {info.pal.map((q) => <i key={q.hex} style={{ background: q.hex, flex: q.p }} title={q.hex} />)}
      </div>
      <div className="dp-pal-legend">
        {info.pal.map((q) => (
          <span key={q.hex}><i className="sw" style={{ background: q.hex }} />{q.name} {Math.round(q.p * 100)}%</span>
        ))}
      </div>
      <div className="dp-stats">
        <div><b><i className="sw" style={{ background: info.rep.hex }} />{info.rep.name}</b>{t('record.repColor')}</div>
        <div><b>{Math.round(info.cf * 100)}</b>{t('record.colorfulness')}</div>
        <div><b>{Math.round(info.L * 100)}</b>{t('record.lightness')}</div>
      </div>
      <h4 className="dp-ex-h">{t('record.relations')}</h4>
      <p className="dp-ex-note muted">{info.scoped ? t('record.relScopedNote') : t('record.relWholeNote')}</p>
      <div className="dp-rels">
        {info.relations.map((rel) => {
          const all = rel.rids.length - 1;
          const inN = rel.inScope.length;
          return (
            <div key={rel.key} className="dp-rel">
              <div className="dp-rel-head">
                <b>{rel.name}</b>
                <span className="muted">{rel.title}</span>
              </div>
              {/* 横に流して見られる縮略図（クリックでその記録の详情へ）。 */}
              <div className="dp-rel-strip">
                {rel.items.map((it) => (
                  <button key={it.rid} type="button" title={it.tag} onClick={() => void drawer.open(it.rid)}>
                    <img src={`${API_BASE_URL}/thumbs/${encodeURIComponent(it.ph)}`} alt="" loading="lazy" />
                  </button>
                ))}
              </div>
              <div className="dp-rel-go">
                <button type="button" className="link-btn" disabled={busy} onClick={() => void openRelation(rel, false)}>
                  {t('record.viewRelationAll', { n: all })}
                </button>
                {info.scoped && (
                  <button type="button" className="link-btn" disabled={busy || inN === 0}
                    onClick={() => void openRelation(rel, true)}>
                    {t('record.viewRelationIn', { n: inN })}
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
