import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { CircleMarker, MapContainer, Popup, TileLayer, useMap } from 'react-leaflet';
import { useNavigate } from 'react-router-dom';
import { ApiError, getMapRecords, getRecord, photoUrl } from '../api/client';
import type { MapQuery, MapRecord, RecordDetail } from '../api/types';
import PhotoThumb from '../components/database/PhotoThumb';
import StatusBadge from '../components/database/StatusBadge';
import useFilterOptions from '../hooks/useFilterOptions';

const ENTRY_MODES = ['quick', 'standard', 'research'];
const DATA_STATUSES = ['raw', 'submitted', 'ai_drafted', 'reviewed', 'verified', 'rejected'];
const FALLBACK_COLOR = '#637083';

/** 併記（"日本語/韓国語"）は先頭言語で色を引く（モバイル版と同じ規則）。 */
const primaryLanguage = (v: string) =>
  v.split(/[/・、,]/).map((s) => s.trim()).filter(Boolean)[0] ?? '';

/** popup の中身。開いた時だけ mount されるので、その時点で詳情を遅延取得して
    補助言語・採集日時・地区コードを補う（/map/records は軽量のまま保つ）。 */
function MapPopupContent({ r }: { r: MapRecord }) {
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
        <div><span>主要言語</span><b>{r.mainLanguage || '—'}</b></div>
        <div><span>補助言語</span><b>{d('補助言語')}</b></div>
        <div><span>地区コード</span><b>{d('地区コード')}</b></div>
        <div><span>採集日時</span><b className="mono">{d('採集日時')}</b></div>
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
        Open in Database
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

export default function MapPage() {
  const [filters, setFilters] = useState<MapQuery>({});
  const [records, setRecords] = useState<MapRecord[] | null>(null);
  const [error, setError] = useState<string | null>(null);
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

  // 凡例: 現在表示中の記録に出てくる言語だけを出す。
  const legend = useMemo(() => {
    const langs = new Set(valid.map((r) => primaryLanguage(r.mainLanguage) || '不明'));
    return [...langs].map((l) => ({ lang: l, color: colorOf(l) }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [valid, schema]);

  const patch = (p: Partial<MapQuery>) => setFilters((f) => ({ ...f, ...p }));
  const sel = (
    label: string,
    value: string,
    options: string[],
    onChange: (v: string) => void,
  ) => (
    <label className="filter-field" key={label}>
      <span>{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">All</option>
        {options.map((o) => (
          <option key={o} value={o}>{o}</option>
        ))}
      </select>
    </label>
  );

  return (
    <div className="map-page">
      <div className="page-header">
        <h1>Map</h1>
        <p>
          Spatial distribution of collected records.{' '}
          <span className="muted">
            Only records with latitude and longitude are shown on the map.
          </span>
        </p>
      </div>

      <div className="card filters-bar">
        {sel('Language', filters.mainLanguage ?? '',
          schema?.enums['主要言語'] ?? [],
          (v) => patch({ mainLanguage: v || undefined }))}
        {sel('Area', filters.areaCode ?? '', areas,
          (v) => patch({ areaCode: v || undefined }))}
        {sel('Mode', filters.entryMode ?? '', ENTRY_MODES,
          (v) => patch({ entryMode: v || undefined }))}
        {sel('Status', filters.dataStatus ?? '', DATA_STATUSES,
          (v) => patch({ dataStatus: v || undefined }))}
        <label className="filter-field">
          <span>Dataset</span>
          <select
            value={filters.datasetId != null ? String(filters.datasetId) : ''}
            onChange={(e) =>
              patch({ datasetId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">All</option>
            {datasets.map((d) => (
              <option key={d.id} value={d.id}>{`#${d.id} ${d.name}`}</option>
            ))}
          </select>
        </label>
        <span className="spacer" />
        <span className="muted total">
          {records != null ? `${valid.length} mapped records` : ''}
        </span>
        <button className="btn" onClick={() => setFilters({})}>Clear filters</button>
        <button className="btn" onClick={fetchRecords}>Refresh</button>
      </div>

      {error && (
        <div className="error-box">
          <strong>Could not load map records.</strong>
          <div className="hint">{error}</div>
        </div>
      )}

      {!error && records != null && valid.length === 0 && (
        <div className="placeholder">
          <p>
            {Object.values(filters).some((v) => v !== undefined)
              ? 'No mapped records match the current filters.'
              : 'No records with GPS yet. Import a Dataset Package that contains coordinates.'}
          </p>
        </div>
      )}

      <div className="map-wrap card">
        <MapContainer
          center={[35.6021, 139.7011]}
          zoom={13}
          className="map-canvas"
          scrollWheelZoom
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <FitBounds records={valid} />
          {valid.map((r) => (
            <CircleMarker
              key={r.id}
              center={[r.lat, r.lng]}
              radius={9}
              pathOptions={{
                color: '#ffffff',
                weight: 2,
                fillColor: colorOf(r.mainLanguage),
                fillOpacity: 0.9,
              }}
            >
              <Popup minWidth={240}>
                <MapPopupContent r={r} />
              </Popup>
            </CircleMarker>
          ))}
        </MapContainer>

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
