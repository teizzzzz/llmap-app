import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { MapContainer, Marker, TileLayer, Tooltip, useMap } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import { ApiError, getMapRecords, photoUrl } from '../../api/client';
import type { MapQuery, MapRecord } from '../../api/types';
import { mapViews } from '../../lib/browseMemory';
import LangTags from '../LangTags';
import { LANG_COLOR, primaryLangCode } from '../../lib/langColors';

// 資料庫の「地図」視図: 資料庫と同じ範囲（筛选・記録集合）の空間分布。
// 範囲の条件は資料庫の筛选栏が持つので、ここには言語の表示切替だけを置く。

/** 言語色の丸マーカー（divIcon）。クラスタリングは L.Marker のみ対象のため、
    CircleMarker ではなく divIcon 化した Marker を使う。色ごとにキャッシュ。 */
const dotIconCache = new Map<string, L.DivIcon>();
const dotIcon = (color: string): L.DivIcon => {
  let icon = dotIconCache.get(color);
  if (!icon) {
    icon = L.divIcon({
      className: '',
      html: `<span class="map-dot" style="background:${color}"></span>`,
      iconSize: [8, 8],
      iconAnchor: [4, 4],
      popupAnchor: [0, -6],
    });
    dotIconCache.set(color, icon);
  }
  return icon;
};

/** 点に乗せたときの小さな見本（写真・編号・言語）。クリックで共通の详情を開く。 */
function MapPreview({ r }: { r: MapRecord }) {
  return (
    <div className="map-preview">
      <img src={photoUrl(`/records/${r.id}/thumb`) ?? ''} alt="" />
      <div className="map-preview-t">
        <b className="mono">{r.displayId || r.signId}</b>
        <LangTags value={r.mainLanguage} />
      </div>
    </div>
  );
}

/** 開いている記録の印（黒い輪）。 */
const openIcon = L.divIcon({
  className: '',
  html: '<span class="map-dot map-dot--open"></span>',
  iconSize: [14, 14],
  iconAnchor: [7, 7],
  popupAnchor: [0, -8],
});

/** 記録群が変わったら全 marker が収まるように地図を移動する。 */
function FitBounds({ records, fitKey }: { records: MapRecord[]; fitKey: string }) {
  const map = useMap();
  // 範囲が変わったときだけ合わせる（編集で読み直しても見ている位置は動かさない）。
  // 同じ範囲で前に見ていた位置があればそこへ戻す（視図を行き来しても続きから）。
  const fitted = useRef<string | null>(null);
  useEffect(() => {
    if (records.length === 0 || fitted.current === fitKey) return;
    fitted.current = fitKey;
    const saved = mapViews.get(fitKey);
    if (saved) { map.setView(saved.center, saved.zoom, { animate: false }); return; }
    const bounds = L.latLngBounds(records.map((r) => [r.lat, r.lng]));
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 18 });
  }, [records, map, fitKey]);
  useEffect(() => {
    const save = () => {
      if (fitted.current !== fitKey) return;
      const c = map.getCenter();
      mapViews.set(fitKey, { center: [c.lat, c.lng], zoom: map.getZoom() });
    };
    map.on('moveend', save);
    return () => { map.off('moveend', save); };
  }, [map, fitKey]);
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

export default function RecordsMap({ query, version, onOpen, onCount, openId }: {
  query: MapQuery;
  /** 記録の編集などで増える（読み直す）。 */
  version: number;
  onOpen: (id: number) => void;
  /** 地図に出せる（GPS のある）件数。 */
  onCount?: (n: number | null) => void;
  /** 開いている記録（印を付ける）。 */
  openId?: number | null;
}) {
  const { t } = useTranslation();
  const filters = query;
  const filtersKey = JSON.stringify(query);
  const [records, setRecords] = useState<MapRecord[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fullscreen, setFullscreen] = useState(false);

  const fetchRecords = useCallback(() => {
    setError(null);
    getMapRecords(filters)
      .then((rs) => { setRecords(rs); onCount?.(rs.length); })
      .catch((e: unknown) => {
        setRecords(null);
        onCount?.(null);
        setError(e instanceof ApiError ? e.message : String(e));
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filtersKey, version]);
  useEffect(fetchRecords, [fetchRecords]);

  // Esc で全画面解除、F で切替（入力中は無効）。
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setFullscreen(false); return; }
      const el = e.target as HTMLElement | null;
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      if (el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return;
      if (e.key.toLowerCase() === 'f') setFullscreen((v) => !v);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // 経緯度が異常な行は地図に出さない（backend 側は数値保証のみ）。
  const valid = useMemo(
    () => (records ?? []).filter((r) =>
      Number.isFinite(r.lat) && Number.isFinite(r.lng)
      && Math.abs(r.lat) <= 90 && Math.abs(r.lng) <= 180),
    [records],
  );
  const shown = valid;

  return (
    <div className={`map-page map-view${fullscreen ? ' map-page--full' : ''}`}>
      {error && (
        <div className="error-box">
          <strong>{t('map.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {!error && !fullscreen && records != null && valid.length === 0 && (
        <div className="placeholder">
          <p>{Object.values(filters).some((v) => v !== undefined && v !== '') ? t('map.noMatch') : t('map.noGps')}</p>
        </div>
      )}

      <div className="map-wrap">
        {/* 全画面は地図の右上に重ねる（別の行を取らない）。 */}
        <button type="button" className="btn sm map-full-btn" onClick={() => setFullscreen((v) => !v)}>
          {fullscreen ? t('map.exitFull') : t('map.fullscreen')}<kbd>{fullscreen ? 'Esc' : 'F'}</kbd>
        </button>
        <MapContainer center={[35.7016, 139.6984]} zoom={16} maxZoom={22} className="map-canvas" scrollWheelZoom>
          {/* tile.openstreetmap.org はアプリ（Referer 無し）からの利用を 403 で遮断するため
              Esri の街路タイルを使う（キー不要・帰属表記で利用可）。z19 より先は拡大表示。 */}
          <TileLayer
            attribution='Tiles &copy; Esri &mdash; Esri, HERE, Garmin, &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}"
            maxZoom={22}
            maxNativeZoom={19}
          />
          <FitBounds records={valid} fitKey={filtersKey} />
          <InvalidateOnChange dep={fullscreen} />
          {/* 低倍率のみクラスタ表示。z18 以上ではクラスタを解除し、各点を実座標に置く
              （spiderfy は位置が実座標からずれるため使わない）。 */}
          <MarkerClusterGroup
            chunkedLoading
            maxClusterRadius={40}
            disableClusteringAtZoom={18}
            spiderfyOnMaxZoom={false}
            showCoverageOnHover={false}
          >
            {shown.map((r) => (
              <Marker key={r.id} position={[r.lat, r.lng]} eventHandlers={{ click: () => onOpen(r.id) }} zIndexOffset={r.id === openId ? 1000 : 0}
                icon={r.id === openId ? openIcon : dotIcon(LANG_COLOR[primaryLangCode(r.mainLanguage)])}>
                <Tooltip direction="top" offset={[0, -8]} opacity={1} className="map-tip">
                  <MapPreview r={r} />
                </Tooltip>
              </Marker>
            ))}
          </MarkerClusterGroup>
        </MapContainer>
      </div>

    </div>
  );
}
