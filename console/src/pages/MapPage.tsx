import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import { useNavigate } from 'react-router-dom';
import { ApiError, getMapRecords, getRecord, photoUrl } from '../api/client';
import type { MapQuery, MapRecord, RecordDetail } from '../api/types';
import PhotoThumb from '../components/database/PhotoThumb';
import StatusBadge from '../components/database/StatusBadge';
import useFilterOptions from '../hooks/useFilterOptions';

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'reviewed', 'verified', 'rejected'];
const FALLBACK_COLOR = '#637083';

/** 併記（"日本語/韓国語"）は先頭言語で色を引く（モバイル版と同じ規則）。 */
const primaryLanguage = (v: string) =>
  v.split(/[/・、,]/).map((s) => s.trim()).filter(Boolean)[0] ?? '';

/** 言語色の丸マーカー（divIcon）。クラスタリングは L.Marker のみ対象のため、
    CircleMarker ではなく divIcon 化した Marker を使う。色ごとにキャッシュ。 */
const dotIconCache = new Map<string, L.DivIcon>();
const dotIcon = (color: string): L.DivIcon => {
  let icon = dotIconCache.get(color);
  if (!icon) {
    icon = L.divIcon({
      className: '',
      html: `<span class="map-dot" style="background:${color}"></span>`,
      iconSize: [16, 16],
      iconAnchor: [8, 8],
      popupAnchor: [0, -8],
    });
    dotIconCache.set(color, icon);
  }
  return icon;
};

/** popup の中身。開いた時だけ mount されるので、その時点で詳情を遅延取得して
    補助言語・採集日時・地区コードを補う（/map/records は軽量のまま保つ）。 */
function MapPopupContent({ r }: { r: MapRecord }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [detail, setDetail] = useState<RecordDetail | null>(null);
  useEffect(() => {
    getRecord(r.id).then(setDetail).catch(() => {});
  }, [r.id]);
  const d = (k: string) => detail?.data[k] || '—';
  return (
    <div className="map-popup">
      <PhotoThumb src={photoUrl(r.photoUrl)} size={110} alt={r.signId} />
      <div className="map-popup-title mono">{r.displayId || r.signId}</div>
      <div className="map-popup-rows">
        <div><span>{t('fields.主要言語')}</span><b>{r.mainLanguage || '—'}</b></div>
        <div><span>{t('fields.補助言語')}</span><b>{d('補助言語')}</b></div>
        <div><span>{t('fields.地区コード')}</span><b>{d('地区コード')}</b></div>
        <div><span>{t('fields.採集日時')}</span><b className="mono">{d('採集日時')}</b></div>
        <div className="map-popup-badges">
          <StatusBadge value={r.entryMode} />
          <StatusBadge value={r.dataStatus} />
        </div>
      </div>
      <button
        className="btn primary"
        style={{ width: '100%', marginTop: 8 }}
        onClick={() => navigate(`/database?record=${r.id}`)}
      >
        {t('common.openInDatabase')}
      </button>
    </div>
  );
}

/** 記録群が変わったら全 marker が収まるように地図を移動する。 */
function FitBounds({ records }: { records: MapRecord[] }) {
  const map = useMap();
  useEffect(() => {
    if (records.length === 0) return;
    const bounds = L.latLngBounds(records.map((r) => [r.lat, r.lng]));
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 17 });
  }, [records, map]);
  return null;
}

/** 全画面切替などでコンテナ寸法が変わったら Leaflet に再計測させる。 */
function InvalidateOnChange({ dep }: { dep: unknown }) {
  const map = useMap();
  useEffect(() => {
    const timer = setTimeout(() => map.invalidateSize(), 60);
    return () => clearTimeout(timer);
  }, [dep, map]);
  return null;
}

export default function MapPage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<MapQuery>({});
  const [records, setRecords] = useState<MapRecord[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fullscreen, setFullscreen] = useState(false);
  const [showFilters, setShowFilters] = useState(true);
  const { schema, datasets, areas } = useFilterOptions();

  const fetchRecords = useCallback(() => {
    setError(null);
    getMapRecords(filters)
      .then(setRecords)
      .catch((e: unknown) => {
        setRecords(null);
        setError(e instanceof ApiError ? e.message : String(e));
      });
  }, [filters]);
  useEffect(fetchRecords, [fetchRecords]);

  // Esc で全画面解除。
  useEffect(() => {
    if (!fullscreen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setFullscreen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [fullscreen]);

  // 経緯度が異常な行は地図に出さない（backend 側は数値保証のみ）。
  const valid = useMemo(
    () =>
      (records ?? []).filter(
        (r) =>
          Number.isFinite(r.lat) && Number.isFinite(r.lng) &&
          Math.abs(r.lat) <= 90 && Math.abs(r.lng) <= 180,
      ),
    [records],
  );

  const colorOf = (lang: string) =>
    schema?.language_colors[primaryLanguage(lang)] ?? FALLBACK_COLOR;

  // 凡例: 現在表示中の記録に出てくる言語だけを出す。言語名はデータなので
  // 原文表示、欠落時のみ翻訳した「不明」ラベルを使う。
  const unknownLabel = t('map.unknownLanguage');
  const legend = useMemo(() => {
    const langs = new Set(valid.map((r) => primaryLanguage(r.mainLanguage) || unknownLabel));
    return [...langs].map((l) => ({ lang: l, color: colorOf(l) }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [valid, schema, unknownLabel]);

  const patch = (p: Partial<MapQuery>) => setFilters((f) => ({ ...f, ...p }));
  const sel = (
    label: string,
    value: string,
    options: { value: string; label: string }[],
    onChange: (v: string) => void,
  ) => (
    <label className="filter-field" key={label}>
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">{t('common.all')}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </label>
  );
  const raw = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  const translated = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));

  return (
    <div className={`map-page${fullscreen ? ' map-page--full' : ''}`}>
      {!fullscreen && (
        <div className="page-header">
          <h1>{t('map.title')}</h1>
          <p>
            {t('map.subtitle')}{' '}
            <span className="muted">{t('map.gpsNote')}</span>
          </p>
        </div>
      )}

      {showFilters && (
        <div className="card filters-bar">
          {sel(t('filters.language'), filters.mainLanguage ?? '',
            raw(schema?.enums['主要言語'] ?? []),
            (v) => patch({ mainLanguage: v || undefined }))}
          {sel(t('filters.area'), filters.areaCode ?? '', raw(areas),
            (v) => patch({ areaCode: v || undefined }))}
          {sel(t('filters.mode'), filters.entryMode ?? '', translated(ENTRY_MODES),
            (v) => patch({ entryMode: v || undefined }))}
          {sel(t('filters.status'), filters.dataStatus ?? '', translated(DATA_STATUSES),
            (v) => patch({ dataStatus: v || undefined }))}
          <label className="filter-field">
            <span>{t('filters.dataset')}</span>
            <select
              value={filters.datasetId != null ? String(filters.datasetId) : ''}
              onChange={(e) =>
                patch({ datasetId: e.target.value ? Number(e.target.value) : undefined })}
            >
              <option value="">{t('common.all')}</option>
              {datasets.map((d) => (
                <option key={d.id} value={d.id}>{`#${d.id} ${d.name}`}</option>
              ))}
            </select>
          </label>
          <span className="spacer" />
          <span className="muted total">
            {records != null ? t('map.mapped', { n: valid.length }) : ''}
          </span>
          <button className="btn" onClick={() => setFilters({})}>{t('common.clearFilters')}</button>
          <button className="btn" onClick={fetchRecords}>{t('common.refresh')}</button>
        </div>
      )}

      {error && (
        <div className="error-box">
          <strong>{t('map.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {!error && !fullscreen && records != null && valid.length === 0 && (
        <div className="placeholder">
          <p>
            {Object.values(filters).some((v) => v !== undefined)
              ? t('map.noMatch')
              : t('map.noGps')}
          </p>
        </div>
      )}

      <div className="map-wrap card">
        <MapContainer
          center={[35.6021, 139.7011]}
          zoom={13}
          maxZoom={22}
          className="map-canvas"
          scrollWheelZoom
        >
          {/* OSM タイルはネイティブ z19 まで。z20–22 は z19 タイルの拡大表示
              （overzoom）で、街路調査の密集点を分離できる深さまで寄れる。 */}
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            maxZoom={22}
            maxNativeZoom={19}
          />
          <FitBounds records={valid} />
          <InvalidateOnChange dep={`${fullscreen}-${showFilters}`} />
          {/* 低倍率のみクラスタ表示。z18 以上ではクラスタを完全に解除し、
              各点を実際の GPS 座標にそのまま置く。spiderfy（クリックで点を
              放射状に散らす表示）は位置が実座標からずれるため使わない。 */}
          <MarkerClusterGroup
            chunkedLoading
            maxClusterRadius={48}
            disableClusteringAtZoom={18}
            spiderfyOnMaxZoom={false}
            showCoverageOnHover={false}
          >
            {valid.map((r) => (
              <Marker
                key={r.id}
                position={[r.lat, r.lng]}
                icon={dotIcon(colorOf(r.mainLanguage))}
              >
                <Popup minWidth={240}>
                  <MapPopupContent r={r} />
                </Popup>
              </Marker>
            ))}
          </MarkerClusterGroup>
        </MapContainer>

        {/* 地図上の操作: 全画面・筛选の折りたたみ */}
        <div className="map-actions">
          <button
            className="btn"
            onClick={() => setShowFilters((v) => !v)}
            title={t('map.toggleFilters')}
          >
            ☰
          </button>
          <button
            className="btn"
            onClick={() => setFullscreen((v) => !v)}
            title={fullscreen ? t('map.exitFull') : t('map.fullscreen')}
          >
            {fullscreen ? '🗗' : '⛶'}
          </button>
        </div>

        {legend.length > 0 && (
          <div className="map-legend card">
            {legend.map(({ lang, color }) => (
              <div key={lang} className="legend-row">
                <span className="legend-dot" style={{ background: color }} />
                {lang}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
