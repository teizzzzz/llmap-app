import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import { useNavigate } from 'react-router-dom';
import { ApiError, getMapRecords, getRecord, photoUrl } from '../api/client';
import type { MapQuery, MapRecord, RecordDetail } from '../api/types';
import { SelectDropdown } from '../components/Dropdown';
import LangTags from '../components/LangTags';
import PhotoThumb from '../components/database/PhotoThumb';
import StatusBadge from '../components/database/StatusBadge';
import useFilterOptions from '../hooks/useFilterOptions';
import { enumLabel } from '../lib/enumLabels';
import {
  CANONICAL_BY_CODE, LANG_COLOR, MAIN_LANGS, langCode, primaryLangCode, splitLangs,
  type LangCode,
} from '../lib/langColors';

// 内部値（API に渡る）。表示ラベルのみ翻訳する。
const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review', 'reviewed', 'verified', 'rejected'];

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
        <div><span>{t('fields.主要言語')}</span><LangTags value={r.mainLanguage} /></div>
        <div><span>{t('fields.補助言語')}</span><LangTags value={detail ? d('補助言語') : ''} /></div>
        <div><span>{t('fields.採集日時')}</span><b className="mono">{d('採集日時')}</b></div>
        <div className="map-popup-badges"><StatusBadge value={r.dataStatus} /></div>
      </div>
      <button className="btn primary wide" style={{ marginTop: 8 }}
        onClick={() => navigate(`/database?record=${r.id}`)}>
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
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 18 });
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

type Bounds = { minLat: number; maxLat: number; minLng: number; maxLng: number };

/** 分図（言語ごとの点分布）。全体と同じ範囲を等距投影して SVG に打つ。
    UV 印刷の分版と同じ考え方で、言語ごとの広がりを並べて比べる。 */
function SmallMultiple({ code, points, bounds, solo, onClick }: {
  code: LangCode;
  points: [number, number][];
  bounds: Bounds;
  solo: boolean;
  onClick: () => void;
}) {
  const { t } = useTranslation();
  const W = 360;
  const kx = Math.cos((((bounds.minLat + bounds.maxLat) / 2) * Math.PI) / 180);
  const spanX = Math.max(1e-6, (bounds.maxLng - bounds.minLng) * kx);
  const spanY = Math.max(1e-6, bounds.maxLat - bounds.minLat);
  const H = Math.max(60, Math.min(150, (W * spanY) / spanX));
  const pad = 8;
  const s = Math.min((W - pad * 2) / spanX, (H - pad * 2) / spanY);
  const ox = (W - spanX * s) / 2;
  const oy = (H - spanY * s) / 2;
  const r = points.length < 40 ? 3.2 : 1.8;
  return (
    <button type="button" className={`multiple${solo ? ' solo' : ''}`} onClick={onClick}>
      <span className="multiple-head">
        <span className="lang-tag"><i style={{ background: LANG_COLOR[code] }} />{code === 'other' ? '··' : code.toUpperCase()}</span>
        <span>{code === 'other' ? t('map.otherLanguages') : enumLabel(t, CANONICAL_BY_CODE[code])}</span>
        <span className="spacer" />
        <b>{points.length}</b>
      </span>
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid meet">
        {points.map(([lat, lng], i) => (
          <circle key={i} r={r} fill={LANG_COLOR[code]} fillOpacity={0.85}
            cx={ox + (lng - bounds.minLng) * kx * s}
            cy={H - oy - (lat - bounds.minLat) * s} />
        ))}
      </svg>
    </button>
  );
}

const codesOf = (r: MapRecord): LangCode[] => {
  const cs = splitLangs(r.mainLanguage).map(langCode);
  return cs.length ? [...new Set(cs)] : ['other'];
};

export default function MapPage() {
  const { t } = useTranslation();
  const [filters, setFilters] = useState<MapQuery>({});
  const [records, setRecords] = useState<MapRecord[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fullscreen, setFullscreen] = useState(false);
  // 非表示にした言語（凡例クリックで切替）。主要言語のどれかが表示中なら点を出す。
  const [hidden, setHidden] = useState<Set<LangCode>>(new Set());
  const { datasets, areas } = useFilterOptions();

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
  const shown = useMemo(
    () => valid.filter((r) => codesOf(r).some((c) => !hidden.has(c))),
    [valid, hidden],
  );
  // 言語ごとの点（併記は各言語に数える）。
  const perLang = useMemo(() => {
    const m = new Map<LangCode, [number, number][]>();
    for (const r of valid) {
      for (const c of codesOf(r)) {
        if (!m.has(c)) m.set(c, []);
        m.get(c)!.push([r.lat, r.lng]);
      }
    }
    return m;
  }, [valid]);
  const legendCodes = ([...MAIN_LANGS, 'other'] as LangCode[]).filter((c) => perLang.has(c));
  const bounds = useMemo<Bounds | null>(() => {
    if (!valid.length) return null;
    let minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (const r of valid) {
      minLat = Math.min(minLat, r.lat); maxLat = Math.max(maxLat, r.lat);
      minLng = Math.min(minLng, r.lng); maxLng = Math.max(maxLng, r.lng);
    }
    return { minLat, maxLat, minLng, maxLng };
  }, [valid]);

  const toggle = (c: LangCode) => setHidden((h) => {
    const n = new Set(h);
    if (n.has(c)) n.delete(c); else n.add(c);
    return n;
  });
  const isSolo = (c: LangCode) =>
    !hidden.has(c) && legendCodes.every((x) => x === c || hidden.has(x));
  // 分図クリック: その言語だけを表示（もう一度で全表示に戻す）。
  const solo = (c: LangCode) =>
    setHidden(isSolo(c) ? new Set() : new Set(legendCodes.filter((x) => x !== c)));

  const patch = (p: Partial<MapQuery>) => setFilters((f) => ({ ...f, ...p }));
  const raw = (xs: string[]) => xs.map((x) => ({ value: x, label: x }));
  const translated = (xs: string[]) =>
    xs.map((x) => ({ value: x, label: t(`status.${x}`, { defaultValue: x }) }));

  return (
    <div className={`map-page${fullscreen ? ' map-page--full' : ''}`}>
      {!fullscreen && (
        <div className="page-head">
          <h1>{t('map.title')}<span className="page-count">{records != null ? shown.length : ''}</span></h1>
          <div className="page-actions">
            <SelectDropdown label={t('filters.area')} value={filters.areaCode ?? ''} options={raw(areas)}
              onChange={(v) => patch({ areaCode: v || undefined })} />
            <SelectDropdown label={t('filters.mode')} value={filters.entryMode ?? ''} options={translated(ENTRY_MODES)}
              onChange={(v) => patch({ entryMode: v || undefined })} />
            <SelectDropdown label={t('filters.status')} value={filters.dataStatus ?? ''} options={translated(DATA_STATUSES)}
              onChange={(v) => patch({ dataStatus: v || undefined })} />
            <SelectDropdown label={t('filters.dataset')}
              value={filters.datasetId != null ? String(filters.datasetId) : ''}
              options={datasets.map((d) => ({ value: String(d.id), label: d.name }))}
              onChange={(v) => patch({ datasetId: v ? Number(v) : undefined })} />
            <button className="btn" onClick={() => setFullscreen(true)}>
              {t('map.fullscreen')}<kbd>F</kbd>
            </button>
          </div>
        </div>
      )}

      <div className="map-toggles">
        {legendCodes.map((c) => (
          <button key={c} type="button" className={`map-toggle${hidden.has(c) ? '' : ' on'}`}
            onClick={() => toggle(c)}>
            <i style={{ background: LANG_COLOR[c] }} />
            {c === 'other' ? t('map.otherLanguages') : enumLabel(t, CANONICAL_BY_CODE[c])}
            <span className="mono">{perLang.get(c)?.length ?? 0}</span>
          </button>
        ))}
        {fullscreen && (
          <>
            <span className="spacer" />
            <button className="btn" onClick={() => setFullscreen(false)}>{t('map.exitFull')}<kbd>Esc</kbd></button>
          </>
        )}
      </div>

      {error && (
        <div className="error-box">
          <strong>{t('map.loadError')}</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {!error && !fullscreen && records != null && valid.length === 0 && (
        <div className="placeholder">
          <p>{Object.values(filters).some((v) => v !== undefined) ? t('map.noMatch') : t('map.noGps')}</p>
        </div>
      )}

      <div className="map-wrap">
        <MapContainer center={[35.7016, 139.6984]} zoom={16} maxZoom={22} className="map-canvas" scrollWheelZoom>
          {/* tile.openstreetmap.org はアプリ（Referer 無し）からの利用を 403 で遮断するため
              Esri の街路タイルを使う（キー不要・帰属表記で利用可）。z19 より先は拡大表示。 */}
          <TileLayer
            attribution='Tiles &copy; Esri &mdash; Esri, HERE, Garmin, &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}"
            maxZoom={22}
            maxNativeZoom={19}
          />
          <FitBounds records={valid} />
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
              <Marker key={r.id} position={[r.lat, r.lng]}
                icon={dotIcon(LANG_COLOR[primaryLangCode(r.mainLanguage)])}>
                <Popup minWidth={240}>
                  <MapPopupContent r={r} />
                </Popup>
              </Marker>
            ))}
          </MarkerClusterGroup>
        </MapContainer>
      </div>

      {!fullscreen && bounds && legendCodes.length > 0 && (
        <section className="multiples">
          <h3>{t('map.layers')}</h3>
          <div className="multiples-grid">
            {legendCodes.map((c) => (
              <SmallMultiple key={c} code={c} points={perLang.get(c) ?? []} bounds={bounds}
                solo={isSolo(c)} onClick={() => solo(c)} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
