// 相册視図: 筛选結果の写真を原比例の瀑布流（Pinterest 式）で並べる。
// 列への割当は「既知の縦横比で最も短い列へ」を毎回先頭から計算する。
// 比は画像の読込完了時に分かるので、未読込のものは仮の比で置く
// （遅延読込は上から順に進むため、見えている範囲の並びはほぼ動かない）。
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ApiError, getRecords, photoUrl } from '../../api/client';
import type { RecordItem, RecordsQuery } from '../../api/types';
import { copyImageToClipboard } from '../../lib/copyImage';
import { LANG_COLOR, primaryLangCode } from '../../lib/langColors';
import PhotoLightbox, { type LightboxItem } from '../PhotoLightbox';

const PAGE = 60;
const GAP = 12;
const GUESS_RATIO = 1.25; // 未読込の写真の仮の縦横比（縦長の看板が多い）

export const THUMB_MIN = 120;
export const THUMB_MAX = 420;
export const THUMB_DEFAULT = 216;
const THUMB_STORE_KEY = 'llmap.albumThumbPx';

/** 列幅（px）。Ctrl/Alt + ホイールで連続拡縮、前回値は localStorage に保持。 */
export function useThumbSize(): [number, (v: number) => void] {
  const [thumb, setThumb] = useState<number>(() => {
    try {
      const saved = Number(localStorage.getItem(THUMB_STORE_KEY));
      if (Number.isFinite(saved) && saved >= THUMB_MIN && saved <= THUMB_MAX) return saved;
    } catch { /* localStorage 不可でも既定値で動く */ }
    return THUMB_DEFAULT;
  });
  useEffect(() => {
    try { localStorage.setItem(THUMB_STORE_KEY, String(thumb)); } catch { /* 同上 */ }
  }, [thumb]);
  return [thumb, setThumb];
}

export default function RecordsMasonry({
  filters,
  thumb,
  onThumb,
  onTotal,
}: {
  filters: RecordsQuery;
  thumb: number;
  onThumb: (v: number) => void;
  onTotal: (n: number | null) => void;
}) {
  const { t } = useTranslation();
  const [items, setItems] = useState<RecordItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const ratios = useRef(new Map<number, number>());
  const [ratioVer, bump] = useState(0);

  const loadPage = useCallback((p: number) => {
    setLoading(true);
    setError(null);
    getRecords({ ...filters, hasPhoto: true, page: p, pageSize: PAGE })
      .then((res) => {
        setItems((prev) => (p === 1 ? res.items : [...prev, ...res.items]));
        setTotal(res.total);
        onTotal(res.total);
        setPage(p);
      })
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [filters, onTotal]);
  useEffect(() => loadPage(1), [loadPage]);

  // 容器幅 → 列数。
  const wrapRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setWidth(e.contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const cols = Math.max(1, Math.floor((width + GAP) / (thumb + GAP)));
  const colW = width ? (width - GAP * (cols - 1)) / cols : thumb;

  const columns = useMemo(() => {
    const out: { r: RecordItem; i: number }[][] = Array.from({ length: cols }, () => []);
    const h = new Array(cols).fill(0);
    items.forEach((r, i) => {
      let k = 0;
      for (let c = 1; c < cols; c++) if (h[c] < h[k]) k = c;
      out[k].push({ r, i });
      h[k] += colW * (ratios.current.get(r.id) ?? GUESS_RATIO) + GAP;
    });
    return out;
    // ratios は ref。読込完了のたびに bump で再計算させる。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items, cols, colW, ratioVer]);

  // Ctrl / Alt + ホイールで列幅を連続拡縮（ビューア表示中はビューア側のズームに譲る）。
  useEffect(() => {
    if (lightboxIndex != null) return;
    const onWheel = (e: WheelEvent) => {
      if (!e.ctrlKey && !e.altKey) return;
      e.preventDefault(); // ブラウザのページズームを抑止
      const factor = e.deltaY < 0 ? 1.08 : 1 / 1.08;
      onThumb(Math.round(Math.min(THUMB_MAX, Math.max(THUMB_MIN, thumb * factor))));
    };
    window.addEventListener('wheel', onWheel, { passive: false });
    return () => window.removeEventListener('wheel', onWheel);
  }, [lightboxIndex, thumb, onThumb]);

  // 無限スクロール: 末尾の哨兵が視界に近づいたら次页を読む。
  const sentinelRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting) && !loading && items.length < total) {
          loadPage(page + 1);
        }
      },
      { rootMargin: '800px 0px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [loadPage, loading, items.length, total, page]);

  const flash = (key: string) => {
    setCopied(key);
    setTimeout(() => setCopied((c) => (c === key ? null : c)), 1400);
  };
  // 复制は原図（縮略図ではなく）— 排版に使える解像度で剪贴板へ。
  const copyImage = async (r: RecordItem) => {
    const url = photoUrl(`/records/${r.id}/photo`);
    if (!url) return;
    try { await copyImageToClipboard(url); flash(`${r.id}:img`); } catch { flash(`${r.id}:err`); }
  };
  const copyId = async (r: RecordItem) => {
    try { await navigator.clipboard.writeText(r.DisplayID || r.SignID); flash(`${r.id}:id`); } catch { flash(`${r.id}:err`); }
  };

  const lightboxItems: LightboxItem[] = items.map((r) => ({
    title: r.DisplayID || r.SignID,
    cropUrl: photoUrl(`/records/${r.id}/photo`),
    sourceUrl: r.元写真ファイル名 ? photoUrl(`/records/${r.id}/source-photo`) : null,
  }));

  return (
    <>
      {error && <div className="error-box"><div className="hint">{error}</div></div>}
      {!error && !loading && items.length === 0 && (
        <div className="placeholder"><p>{t('database.albumNoPhotos')}</p></div>
      )}
      <div className="masonry" ref={wrapRef}>
        {columns.map((col, c) => (
          <div key={c} className="masonry-col" style={{ width: colW }}>
            {col.map(({ r, i }) => {
              const id = r.DisplayID || r.SignID;
              const state = copied?.startsWith(`${r.id}:`) ? copied.split(':')[1] : null;
              return (
                <div key={r.id} className="tile"
                  style={{ aspectRatio: `1 / ${ratios.current.get(r.id) ?? GUESS_RATIO}` }}>
                  <button type="button" className="tile-img" onClick={() => setLightboxIndex(i)}>
                    <img
                      src={photoUrl(r.thumbnailUrl) ?? undefined}
                      alt={id}
                      loading="lazy"
                      decoding="async"
                      onLoad={(e) => {
                        const im = e.currentTarget;
                        if (im.naturalWidth && !ratios.current.has(r.id)) {
                          ratios.current.set(r.id, im.naturalHeight / im.naturalWidth);
                          bump((n) => n + 1);
                        }
                      }}
                    />
                  </button>
                  <i className="tile-lang" style={{ background: LANG_COLOR[primaryLangCode(r.主要言語)] }} />
                  <div className="tile-bar">
                    <button type="button" className="tile-id mono" title={t('database.copyId')}
                      onClick={() => copyId(r)}>
                      {state === 'id' ? '✓' : id}
                    </button>
                    <button type="button" className="tile-copy" title={t('database.copyImage')}
                      onClick={() => copyImage(r)}>
                      {state === 'img' ? '✓' : state === 'err' ? '✗' : t('database.copy')}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        ))}
      </div>
      <div ref={sentinelRef} style={{ height: 1 }} />
      {loading && items.length > 0 && <div className="muted load-more">{t('database.loading')}</div>}
      {lightboxIndex != null && (
        <PhotoLightbox items={lightboxItems} index={lightboxIndex} onClose={() => setLightboxIndex(null)} />
      )}
    </>
  );
}

/** 列幅スライダー（筛选栏の右端に置く。ラベル無し・− / + のみ）。 */
export function ThumbSlider({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  const { t } = useTranslation();
  return (
    <label className="thumb-slider" title={t('database.thumbSize')}>
      <span aria-hidden="true">−</span>
      <input type="range" min={THUMB_MIN} max={THUMB_MAX} step={4} value={value}
        onChange={(e) => onChange(Number(e.target.value))} />
      <span aria-hidden="true">+</span>
    </label>
  );
}
