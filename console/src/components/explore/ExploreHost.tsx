import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { API_BASE_URL } from '../../api/client';
import useExplore from './ExploreContext';

type Rect = { top: number; left: number; width: number; height: number; clipTop: number; clipBottom: number };

/** 探索の画布（iframe）を 1 つだけ持ち、いま表示中の画面が置いた枠（slot）の上に
    重ねる。枠が無いときは裏に置いたまま（読み直さない —— 範囲・位置・関係画布が残る。
    记录详情の色・関連もここで計算する）。display:none にすると iframe の寸法が 0 になり
    配置が崩れるので、隠すときも同じ大きさのまま不可視にする。 */
export default function ExploreHost() {
  const { t, i18n } = useTranslation();
  const ex = useExplore();
  const [rect, setRect] = useState<Rect | null>(null);
  const [full, setFull] = useState(false);
  const last = useRef('');
  // 言語は最初の読み込み時のものを URL に（後の切替はメッセージで。読み直さない）。
  const lang0 = useRef(i18n.language.startsWith('ja') ? 'ja' : 'zh');

  // 枠の位置を追う（スクロール・寸法・見出しの折返しで動くので毎フレーム確認）。
  useEffect(() => {
    const el = ex.slot?.el;
    if (!el) { setRect(null); last.current = ''; return; }
    let raf = 0;
    const tick = () => {
      const r = el.getBoundingClientRect();
      // 枠がスクロール領域（.content）からはみ出す部分は隠す（見出しの上に重ならない）。
      const box = el.closest('.is-full') ? null : el.closest('.content')?.getBoundingClientRect();
      const clipTop = box ? Math.max(0, box.top - r.top) : 0;
      const clipBottom = box ? Math.max(0, r.bottom - box.bottom) : 0;
      const k = `${r.top}|${r.left}|${r.width}|${r.height}|${clipTop}|${clipBottom}`;
      if (k !== last.current) {
        last.current = k;
        setRect({ top: r.top, left: r.left, width: r.width, height: r.height, clipTop, clipBottom });
        setFull(!!el.closest('.is-full'));
      }
      raf = requestAnimationFrame(tick);
    };
    tick();
    return () => cancelAnimationFrame(raf);
  }, [ex.slot]);

  const src = ex.bundleKey
    ? `explore/index.html?v=8&embed=1&lang=${lang0.current}&key=${ex.bundleKey}&api=${encodeURIComponent(API_BASE_URL)}`
    : null;
  const running = ex.job?.status === 'running';
  const empty = ex.job?.status === 'done' && ex.job.count === 0;
  const shown = rect != null && rect.width > 0 && rect.height > 0;
  const style: React.CSSProperties = shown
    ? {
      top: rect.top, left: rect.left, width: rect.width, height: rect.height,
      clipPath: rect.clipTop || rect.clipBottom ? `inset(${rect.clipTop}px 0 ${rect.clipBottom}px 0)` : undefined,
    }
    : { top: 0, left: 0, width: '100vw', height: '100vh' };

  return (
    <div className={`explore-host${shown ? '' : ' is-hidden'}${full ? ' is-full' : ''}`}
      style={style} aria-hidden={!shown}>
      {src && !empty && (
        <iframe key={src} ref={ex.frameRef} src={src} title={t('explore.canvas')} />
      )}
      {(!src || empty || ex.error) && shown && (
        <div className="explore-wait muted">
          {ex.error ? (
            <>
              <strong>{t('explore.failed')}</strong>
              <p className="explore-wait-hint">{ex.error}</p>
            </>
          ) : empty ? (
            <p>{t('explore.empty')}</p>
          ) : (
            <>
              <p>{running && ex.job
                ? t(`explore.phase.${ex.job.phase}`, { done: ex.job.done, total: ex.job.total })
                : t('explore.loading')}</p>
              {running && ex.job && (
                <span className="job-bar"><i style={{ width: `${ex.job.total ? (ex.job.done / ex.job.total) * 100 : 0}%` }} /></span>
              )}
              <p className="explore-wait-hint">{t('explore.firstTimeHint')}</p>
            </>
          )}
        </div>
      )}
      {src && running && shown && <div className="explore-veil">{t('explore.rebuilding')}</div>}
      {/* 画布の上の操作（分組・全貌・全画面など）。各画面が portal で描く。 */}
      <div className="canvas-tools-layer" ref={ex.setToolsEl} />
    </div>
  );
}
