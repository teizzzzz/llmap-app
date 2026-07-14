// 統一写真ビューア（Step 17）。Database 詳情・Review・相册グリッドで共用する。
// 機能: ズーム（ホイール / ±）・ドラッグ平移・fit / 1:1・回転・裁切/元写真切替・
//       前後移動（← →）・ダウンロード・Esc で閉じる・ピクセル寸法表示。
import {
  useCallback, useEffect, useMemo, useRef, useState,
} from 'react';
import { useTranslation } from 'react-i18next';

export interface LightboxItem {
  title: string; // DisplayID / SignID
  cropUrl: string | null;
  sourceUrl: string | null;
}

export default function PhotoLightbox({
  items,
  index,
  initialView = 'crop',
  onClose,
}: {
  items: LightboxItem[];
  index: number;
  initialView?: 'crop' | 'source';
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const [idx, setIdx] = useState(index);
  const [view, setView] = useState<'crop' | 'source'>(initialView);
  const [scale, setScale] = useState<number | 'fit'>('fit');
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [rotation, setRotation] = useState(0);
  const [natural, setNatural] = useState<{ w: number; h: number } | null>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const drag = useRef<{ x: number; y: number; ox: number; oy: number } | null>(null);

  const item = items[idx];
  // 現在ビューの URL。無い側しか無ければ有る側へフォールバック。
  const url = useMemo(() => {
    if (!item) return null;
    if (view === 'crop') return item.cropUrl ?? item.sourceUrl;
    return item.sourceUrl ?? item.cropUrl;
  }, [item, view]);

  /** 自然寸法を取り込む。寸法が分かるまで画像は不可視にしておくことで、
      「原寸の巨大表示 → onLoad 後に fit へスナップ」という開閉時の
      ちらつき（一閃）を根本的に防ぐ（最初の可視フレームが既に fit）。 */
  const syncNatural = useCallback(() => {
    const img = imgRef.current;
    if (img && img.complete && img.naturalWidth > 0) {
      setNatural({ w: img.naturalWidth, h: img.naturalHeight });
    }
  }, []);
  // キャッシュ済み画像は onLoad が発火しないことがあるため、
  // URL 切替のたびに complete 状態を直接確認する。
  useEffect(() => {
    setNatural(null);
    syncNatural();
  }, [url, syncNatural]);

  const reset = useCallback(() => {
    setScale('fit');
    setOffset({ x: 0, y: 0 });
    setRotation(0);
    setNatural(null);
  }, []);

  const go = useCallback((delta: number) => {
    setIdx((i) => Math.min(items.length - 1, Math.max(0, i + delta)));
    reset();
  }, [items.length, reset]);

  /** fit 時の実効スケール（画像とステージの実寸から計算）。 */
  const effectiveScale = useCallback((): number => {
    if (scale !== 'fit') return scale;
    const stage = stageRef.current;
    if (!stage || !natural) return 1;
    const rotated = rotation % 180 !== 0;
    const iw = rotated ? natural.h : natural.w;
    const ih = rotated ? natural.w : natural.h;
    return Math.min(stage.clientWidth / iw, stage.clientHeight / ih, 1);
  }, [scale, natural, rotation]);

  const zoomBy = useCallback((factor: number) => {
    const s = effectiveScale();
    setScale(Math.min(12, Math.max(0.05, s * factor)));
  }, [effectiveScale]);

  // キーボード操作（Esc / ← / → / + / -）。
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      else if (e.key === 'ArrowLeft') go(-1);
      else if (e.key === 'ArrowRight') go(1);
      else if (e.key === '+' || e.key === '=') zoomBy(1.2);
      else if (e.key === '-') zoomBy(1 / 1.2);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose, go, zoomBy]);

  if (!item || !url) return null;
  const s = effectiveScale();

  return (
    <div className="lightbox-overlay" onClick={onClose}>
      {/* ── 顶部工具栏 ── */}
      <div className="lightbox-toolbar" onClick={(e) => e.stopPropagation()}>
        <span className="lightbox-title mono">{item.title}</span>
        {natural && (
          <span className="lightbox-dims">
            {natural.w}×{natural.h}px · {Math.round(s * 100)}%
          </span>
        )}
        <span className="spacer" />
        {item.cropUrl && item.sourceUrl && (
          <div className="lightbox-seg">
            <button
              className={`chip${view === 'crop' ? ' on' : ''}`}
              onClick={() => { setView('crop'); reset(); }}
            >
              {t('record.crop')}
            </button>
            <button
              className={`chip${view === 'source' ? ' on' : ''}`}
              onClick={() => { setView('source'); reset(); }}
            >
              {t('record.source')}
            </button>
          </div>
        )}
        <button className="btn" title="−" onClick={() => zoomBy(1 / 1.2)}>−</button>
        <button className="btn" title="+" onClick={() => zoomBy(1.2)}>＋</button>
        <button className="btn" onClick={() => { setScale('fit'); setOffset({ x: 0, y: 0 }); }}>
          {t('lightbox.fit')}
        </button>
        <button className="btn" onClick={() => { setScale(1); setOffset({ x: 0, y: 0 }); }}>
          1:1
        </button>
        <button className="btn" title={t('lightbox.rotate')}
          onClick={() => setRotation((r) => (r + 90) % 360)}>
          ⟳
        </button>
        <a className="btn" href={url} download>{t('export.download')}</a>
        <button className="btn" onClick={onClose} title="Esc">✕</button>
      </div>

      {/* ── 画像ステージ（ホイールズーム・ドラッグ平移） ── */}
      <div
        ref={stageRef}
        className="lightbox-stage"
        onClick={(e) => e.stopPropagation()}
        onWheel={(e) => zoomBy(e.deltaY < 0 ? 1.12 : 1 / 1.12)}
        onPointerDown={(e) => {
          (e.target as HTMLElement).setPointerCapture(e.pointerId);
          drag.current = { x: e.clientX, y: e.clientY, ox: offset.x, oy: offset.y };
        }}
        onPointerMove={(e) => {
          if (!drag.current) return;
          setOffset({
            x: drag.current.ox + (e.clientX - drag.current.x),
            y: drag.current.oy + (e.clientY - drag.current.y),
          });
        }}
        onPointerUp={() => { drag.current = null; }}
      >
        <img
          ref={imgRef}
          src={url}
          alt={item.title}
          draggable={false}
          onLoad={syncNatural}
          style={{
            transform:
              `translate(${offset.x}px, ${offset.y}px) scale(${s}) rotate(${rotation}deg)`,
            // 寸法判明前は描画しない（fit 計算前の原寸フラッシュ防止）
            visibility: natural ? 'visible' : 'hidden',
          }}
        />
      </div>

      {/* ── 前後ナビ（複数枚のときのみ） ── */}
      {items.length > 1 && (
        <>
          <button
            className="lightbox-nav prev"
            disabled={idx === 0}
            onClick={(e) => { e.stopPropagation(); go(-1); }}
          >
            ‹
          </button>
          <button
            className="lightbox-nav next"
            disabled={idx === items.length - 1}
            onClick={(e) => { e.stopPropagation(); go(1); }}
          >
            ›
          </button>
          <div className="lightbox-counter" onClick={(e) => e.stopPropagation()}>
            {idx + 1} / {items.length}
          </div>
        </>
      )}
    </div>
  );
}
