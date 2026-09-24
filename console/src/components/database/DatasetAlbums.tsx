// Dataset 相册視図（Step 17）: 導入した各 Dataset Package を封面つきカードで
// 一覧し、開くと写真グリッド → クリックで統一ビューア（PhotoLightbox）。
// 「テーブルで表示」でそのデータセットを筛选した表格視図へ移れる。
import { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { API_BASE_URL, ApiError, getRecords, photoUrl } from '../../api/client';
import type { Dataset, RecordItem, RecordsQuery } from '../../api/types';
import useFilterOptions from '../../hooks/useFilterOptions';
import { copyImageToClipboard } from '../../lib/copyImage';
import { languageFilterValues } from '../../lib/languageList';
import PhotoLightbox, { type LightboxItem } from '../PhotoLightbox';
import RecordsFilters from './RecordsFilters';

const PAGE = 60;

// 縮略図の目安幅（px）。排版作業では大きめで内容確認 → 小さめで俯瞰、を
// 行き来するため 3 段階で切り替えられるようにする。
const THUMB_SIZES = [100, 132, 210] as const;

const fmtSize = (n: number) =>
  n >= 1024 ** 3 ? `${(n / 1024 ** 3).toFixed(2)} GB`
  : n >= 1024 ** 2 ? `${(n / 1024 ** 2).toFixed(1)} MB`
  : `${Math.ceil(n / 1024)} KB`;

/** 相册カードの一覧。 */
export function DatasetAlbumGrid({
  datasets,
  onOpen,
}: {
  datasets: Dataset[];
  onOpen: (d: Dataset) => void;
}) {
  const { t } = useTranslation();
  if (datasets.length === 0) {
    return <div className="placeholder"><p>{t('database.noAlbums')}</p></div>;
  }
  return (
    <div className="album-grid">
      {datasets.map((d) => (
        <div key={d.id} className="card album-card" onClick={() => onOpen(d)}>
          {d.coverPhoto ? (
            <img
              className="album-cover"
              src={`${API_BASE_URL}/photos/${encodeURIComponent(d.coverPhoto)}`}
              alt={d.name}
              loading="lazy"
            />
          ) : (
            <div className="album-cover-empty">▦</div>
          )}
          <div className="album-body">
            <div className="album-name" title={d.name}>{d.name}</div>
            <div className="album-meta">
              {t('database.albumMeta', {
                n: d.liveRecordCount ?? d.record_count,
                size: fmtSize(d.photoBytes ?? 0),
              })}
            </div>
            <div className="album-meta">
              {t('database.importedOn', { date: d.imported_at.slice(0, 10) })}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

/** 1 つの Dataset の写真グリッド（分页ロード＋ビューア）。 */
export function DatasetPhotoGrid({
  dataset,
  onBack,
  onOpenInTable,
}: {
  dataset: Dataset;
  onBack: () => void;
  onOpenInTable: () => void;
}) {
  const { t } = useTranslation();
  const [items, setItems] = useState<RecordItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);
  // 相册内の快速筛选（datasetId / hasPhoto は固定でマージする）。
  const [filters, setFilters] = useState<RecordsQuery>({});
  const [thumb, setThumb] = useState<number>(THUMB_SIZES[1]);
  // 复制フィードバック: "<recordId>:img|id|err" を短時間 ✓/✗ 表示。
  const [copied, setCopied] = useState<string | null>(null);
  const options = useFilterOptions();

  const loadPage = useCallback((p: number) => {
    setLoading(true);
    setError(null);
    getRecords({
      ...filters, datasetId: dataset.id, datasetIds: undefined,
      hasPhoto: true, page: p, pageSize: PAGE,
    })
      .then((res) => {
        setItems((prev) => (p === 1 ? res.items : [...prev, ...res.items]));
        setTotal(res.total);
        setPage(p);
      })
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [dataset.id, filters]);
  useEffect(() => loadPage(1), [loadPage]);

  // 無限スクロール: 末尾の哨兵が視界に近づいたら（600px 手前で先読み）
  // 次页を自動ロードする。「加载更多」ボタンは廃止。
  const sentinelRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)
            && !loading && items.length < total) {
          loadPage(page + 1);
        }
      },
      { rootMargin: '600px 0px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [loadPage, loading, items.length, total, page]);

  const flash = (key: string) => {
    setCopied(key);
    setTimeout(() => setCopied((c) => (c === key ? null : c)), 1400);
  };
  const doCopyImage = async (r: RecordItem) => {
    const url = photoUrl(r.thumbnailUrl);
    if (!url) return;
    try {
      await copyImageToClipboard(url);
      flash(`${r.id}:img`);
    } catch {
      flash(`${r.id}:err`);
    }
  };
  const doCopyId = async (r: RecordItem) => {
    try {
      await navigator.clipboard.writeText(r.DisplayID || r.SignID);
      flash(`${r.id}:id`);
    } catch {
      flash(`${r.id}:err`);
    }
  };

  const lightboxItems: LightboxItem[] = items.map((r) => ({
    title: r.DisplayID || r.SignID,
    cropUrl: photoUrl(r.thumbnailUrl),
    sourceUrl: r.元写真ファイル名
      ? photoUrl(`/records/${r.id}/source-photo`)
      : null,
  }));

  return (
    <>
      <div className="card filters-bar" style={{ marginBottom: 14 }}>
        <button className="btn" onClick={onBack}>{t('database.backToAlbums')}</button>
        <strong style={{ marginLeft: 4 }}>{dataset.name}</strong>
        <span className="muted">
          {t('database.albumMeta', {
            n: dataset.liveRecordCount ?? dataset.record_count,
            size: fmtSize(dataset.photoBytes ?? 0),
          })}
        </span>
        <span className="spacer" />
        {/* 縮略図サイズ（小/中/大） */}
        {THUMB_SIZES.map((s, i) => (
          <button
            key={s}
            className="btn"
            style={thumb === s ? { fontWeight: 700 } : undefined}
            title={t('database.thumbSize')}
            onClick={() => setThumb(s)}
          >
            {[t('database.sizeS'), t('database.sizeM'), t('database.sizeL')][i]}
          </button>
        ))}
        <button className="btn" onClick={onOpenInTable}>
          {t('database.openInTable')}
        </button>
      </div>

      {/* 相册内の快速筛选（語言・状態・字段筛选…。データセットは固定） */}
      <RecordsFilters
        value={filters}
        options={{
          languages: languageFilterValues(options.schema?.enums['主要言語']),
          areas: options.areas,
          collectors: options.collectors,
          datasets: [],
        }}
        schemaEnums={options.schema?.enums}
        fieldPresence={options.fieldStats}
        hideDatasets
        total={total}
        onChange={(patch) => setFilters((f) => ({ ...f, ...patch }))}
        onClear={() => setFilters({})}
        onRefresh={() => loadPage(1)}
      />

      {error && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <div className="hint">{error}</div>
        </div>
      )}
      {!error && !loading && items.length === 0 && (
        <div className="placeholder"><p>{t('database.albumNoPhotos')}</p></div>
      )}

      <div
        className="photo-grid"
        style={{
          gridTemplateColumns: `repeat(auto-fill, minmax(${thumb}px, 1fr))`,
        }}
      >
        {items.map((r, i) => (
          <div key={r.id} className="cell-wrap">
            <button
              type="button"
              className="cell"
              title={r.DisplayID || r.SignID}
              onClick={() => setLightboxIndex(i)}
            >
              <img
                src={photoUrl(r.thumbnailUrl) ?? undefined}
                alt={r.SignID}
                loading="lazy"
              />
            </button>
            {/* 悬停操作: 画像を剪贴板へ（InDesign/Illustrator に直接粘贴）・ID 复制 */}
            <div className="cell-actions" onClick={(e) => e.stopPropagation()}>
              <button
                type="button"
                className="cell-act"
                title={t('database.copyImage')}
                onClick={() => doCopyImage(r)}
              >
                {copied === `${r.id}:img` ? '✓'
                  : copied === `${r.id}:err` ? '✗' : '⧉'}
              </button>
              <button
                type="button"
                className="cell-act"
                title={t('database.copyId')}
                onClick={() => doCopyId(r)}
              >
                {copied === `${r.id}:id` ? '✓' : 'ID'}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* 無限スクロールの哨兵（これが視界に近づくと次页を自動ロード） */}
      <div ref={sentinelRef} style={{ height: 1 }} />
      {loading && items.length > 0 && (
        <div className="muted" style={{ textAlign: 'center', marginTop: 14 }}>
          {t('database.loading')}
        </div>
      )}

      {lightboxIndex != null && (
        <PhotoLightbox
          items={lightboxItems}
          index={lightboxIndex}
          onClose={() => setLightboxIndex(null)}
        />
      )}
    </>
  );
}
