import { useTranslation } from 'react-i18next';
import useSharedFilters, { hasAnyFilter } from '../../hooks/useSharedFilters';
import useExplore, { type ExploreScope, type ExploreView } from './ExploreContext';

const VIEWS: ExploreView[] = ['explore', 'themes', 'chain'];

/** 探索モードのサイドバー: 画面（照片探索 / 主题 / 接龙）、範囲、生成の状況。
    探索ページ自身の上部リンクは桌面の幅では隠れるため、ここに集める。 */
export default function ExploreSidebar() {
  const { t } = useTranslation();
  const ex = useExplore();
  const shared = useSharedFilters();
  const canDb = hasAnyFilter(shared.filters);
  const nSel = shared.selection.length;
  const running = ex.job?.status === 'running';

  const scopes: { k: ExploreScope; label: string; disabled?: boolean; hint?: string }[] = [
    { k: 'all', label: t('explore.scopeAll') },
    { k: 'db', label: t('explore.scopeDb'), disabled: !canDb, hint: canDb ? undefined : t('explore.noFilter') },
  ];
  if (nSel > 0 || ex.scope === 'sel') scopes.push({ k: 'sel', label: t('explore.scopeSel', { n: nSel }) });

  return (
    <>
      <nav aria-label={t('nav.explore')}>
        {VIEWS.map((v) => (
          <button key={v} type="button"
            className={`nav-item${ex.view === v ? ' active' : ''}`}
            aria-current={ex.view === v ? 'page' : undefined}
            disabled={!ex.bundleKey}
            onClick={() => ex.goView(v)}>
            {t(`explore.view.${v}`)}
          </button>
        ))}
      </nav>

      <section className="ex-side" aria-label={t('explore.scope')}>
        <h3 className="ex-side-h">{t('explore.scope')}</h3>
        <div className="ex-scopes" role="radiogroup" aria-label={t('explore.scope')}>
          {scopes.map((s) => (
            <button key={s.k} type="button" role="radio" aria-checked={ex.scope === s.k}
              className={`ex-scope${ex.scope === s.k ? ' on' : ''}`}
              disabled={s.disabled || running} title={s.hint}
              onClick={() => ex.choose(s.k)}>
              <i aria-hidden="true" />
              {s.label}
            </button>
          ))}
        </div>
        {!canDb && <p className="ex-side-hint">{t('explore.noFilter')}</p>}

        <div className="ex-status" aria-live="polite">
          {running && ex.job ? (
            <>
              <span className="job-bar">
                <i style={{ width: `${ex.job.total ? (ex.job.done / ex.job.total) * 100 : 0}%` }} />
              </span>
              <span>{t(`explore.phase.${ex.job.phase}`, { done: ex.job.done, total: ex.job.total })}</span>
            </>
          ) : ex.job?.status === 'done' ? (
            <span className="ex-count">{t('explore.count', { n: ex.job.count })}</span>
          ) : null}
        </div>
      </section>

      <p className="sidebar-note">{t('nav.exploreNote')}</p>
    </>
  );
}
