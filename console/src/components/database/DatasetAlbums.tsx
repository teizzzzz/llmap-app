// Dataset 相册視図（Step 17）: 導入した各 Dataset Package を封面つきカードで
// 一覧し、開くと写真グリッド → クリックで統一ビューア（PhotoLightbox）。
// 「テーブルで表示」でそのデータセットを筛选した表格視図へ移れる。
import { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { API_BASE_URL, ApiError, getRecords, photoUrl } from '../../api/client';
import type { Dataset, RecordItem } from '../../api/types';
import PhotoLightbox, { type LightboxItem } from '../PhotoLightbox';

const PAGE = 60;

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

  const loadPage = useCallback((p: number) => {
    setLoading(true);
    setError(null);
    getRecords({ datasetId: dataset.id, hasPhoto: true, page: p, pageSize: PAGE })
      .then((res) => {
        setItems((prev) => (p === 1 ? res.items : [...prev, ...res.items]));
        setTotal(res.total);
        setPage(p);
      })
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [dataset.id]);
  useEffect(() => loadPage(1), [loadPage]);

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
        <button className="btn" onClick={onOpenInTable}>
          {t('database.openInTable')}
        </button>
      </div>

      {error && (
        <div className="error-box" style={{ marginBottom: 14 }}>
          <div className="hint">{error}</div>
        </div>
      )}
      {!error && !loading && items.length === 0 && (
        <div className="placeholder"><p>{t('database.albumNoPhotos')}</p></div>
      )}

      <div className="photo-grid">
        {items.map((r, i) => (
          <button
            key={r.id}
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
        ))}
      </div>

      {items.length < total && (
        <div style={{ textAlign: 'center', marginTop: 14 }}>
          <button className="btn" disabled={loading} onClick={() => loadPage(page + 1)}>
            {loading ? t('database.loading') : t('database.loadMore')}
          </button>
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
