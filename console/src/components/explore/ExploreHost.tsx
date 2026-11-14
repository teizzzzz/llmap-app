import { useTranslation } from 'react-i18next';
import { API_BASE_URL } from '../../api/client';
import useExplore from './ExploreContext';

/** 探索区（llmap-view の照片墙・照片云・主题・色轮・关联・接龙）を研究台に埋め込む。
    範囲の写真から本地で作った探索データで console/public/explore/（llmap-view の
    コピー）を iframe で開く。操作（画面・範囲・進捗）はサイドバー（ExploreSidebar）。
    一度開いたら隠すだけで保持する —— 研究と行き来しても閲覧位置が残る。 */
export default function ExploreHost() {
  const { t, i18n } = useTranslation();
  const ex = useExplore();
  const lang = i18n.language.startsWith('ja') ? 'ja' : 'zh';
  const src = ex.bundleKey
    ? `explore/index.html?embed=1&lang=${lang}&key=${ex.bundleKey}&api=${encodeURIComponent(API_BASE_URL)}`
    : null;
  const running = ex.job?.status === 'running';
  const empty = ex.job?.status === 'done' && ex.job.count === 0;

  return (
    // display:none にすると iframe の画面が 0×0 になり、探索側の配置が崩れる。
    // 隠すときも同じ大きさのまま裏に置く（不可視・操作不可）。
    <div className={`explore-host${ex.visible ? '' : ' is-hidden'}`} aria-hidden={!ex.visible}>
      {ex.error && (
        <div className="error-box explore-error">
          <strong>{t('explore.failed')}</strong>
          <div className="hint">{ex.error}</div>
        </div>
      )}
      <div className="explore-frame">
        {empty ? (
          <div className="explore-wait muted"><p>{t('explore.empty')}</p></div>
        ) : src ? (
          // 範囲を変えたら読み直して照片探索から（新しい範囲の写真をまず見せる）。
          // 画面はサイドバーが探索側の知らせ（llmap:view）で追従する。接龙の画板は探索側が保存している。
          <iframe key={src} ref={ex.frameRef} src={src} title={t('nav.explore')} />
        ) : !ex.error && (
          <div className="explore-wait muted">
            <p>{running ? t('explore.preparing') : t('explore.loading')}</p>
            <p className="explore-wait-hint">{t('explore.firstTimeHint')}</p>
          </div>
        )}
        {src && running && <div className="explore-veil">{t('explore.rebuilding')}</div>}
      </div>
    </div>
  );
}
