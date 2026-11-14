import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import useExplore, { useCanvasSlot } from '../components/explore/ExploreContext';

/** 関係画布（接龙・分岔）: 写真から色・位置・言語・類型の関連をたどって並べる自由な画布。
    配置は独自だが、記録は共通の记录详情で開く（ダブルクリック／右の「查看详情」）。 */
export default function CanvasPage() {
  const { t } = useTranslation();
  const ex = useExplore();
  const slotRef = useCanvasSlot('chain');
  const [full, setFull] = useState(false);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      if (e.key === 'Escape' && !document.querySelector('.drawer, .lightbox-overlay, .modal-overlay')) setFull(false);
      if (e.key.toLowerCase() === 'f') setFull((v) => !v);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);
  useEffect(() => {
    document.body.classList.toggle('canvas-full', full);
    return () => document.body.classList.remove('canvas-full');
  }, [full]);
  return (
    <div className="canvas-page">
      <div className={`canvas-area${full ? ' is-full' : ''}`}>
        <div className="canvas-bar">
          <h1 className="canvas-title">{t('canvasPage.title')}</h1>
          <span className="spacer" />
          <button type="button" className="btn sm" disabled={!ex.ready} onClick={ex.fit}>{t('canvas.fit')}</button>
          <button type="button" className="btn sm" onClick={() => setFull((v) => !v)}>
            {full ? t('canvas.exitFull') : t('canvas.full')}<kbd>{full ? 'Esc' : 'F'}</kbd>
          </button>
        </div>
        <div className="canvas-slot" ref={slotRef} />
      </div>
    </div>
  );
}
