// LLMap backend API client。
// base URL は .env の VITE_API_BASE_URL（既定 http://localhost:8000）。
import type {
  AiJobStatus,
  AiPreview,
  AiStatus,
  AppConfig,
  AppConfigUpdate,
  Dataset,
  ExportJobStatus,
  ImportDatasetResult,
  MapQuery,
  MapRecord,
  RecordDetail,
  RecordsQuery,
  RecordsResponse,
  SchemaInfo,
  StatsSummary,
  StorageCleanupResult,
  StorageSummary,
} from './types';

// 桌面版（Tauri shell）は起動時に backend の動的端口を注入する。
// 優先順: ① 運行時注入 ② 編譯期 env ③ 既定 localhost:8000。
// Web dev（npm run dev / VITE_API_BASE_URL）の従来動作は不変。
declare global {
  interface Window {
    __LLMAP_API_BASE_URL__?: string;
  }
}

export const API_BASE_URL: string =
  (typeof window !== 'undefined' && window.__LLMAP_API_BASE_URL__) ||
  import.meta.env.VITE_API_BASE_URL ||
  'http://localhost:8000';

/** 桌面版（Tauri shell）で動いているか。backend は shell が自動起動するため、
    「uvicorn を手で起動して」系の開発者向け案内は桌面版では出さない。 */
export const IS_DESKTOP: boolean =
  typeof window !== 'undefined' && !!window.__LLMAP_API_BASE_URL__;

/** backend 未起動などの通信失敗を UI で見分けるためのエラー型。 */
export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  // FormData（ファイルアップロード）は Content-Type をブラウザに任せる
  // （boundary 付き multipart を自動設定させるため）。
  const isForm = init?.body instanceof FormData;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      headers: isForm ? undefined : { 'Content-Type': 'application/json' },
      ...init,
    });
  } catch {
    throw new ApiError(`Cannot reach backend at ${API_BASE_URL}.`);
  }
  if (!res.ok) {
    let detail = res.statusText;
    try {
      detail = (await res.json()).detail ?? detail;
    } catch {
      /* JSON でないエラー本文は statusText のまま */
    }
    throw new ApiError(`${res.status}: ${detail}`, res.status);
  }
  return (await res.json()) as T;
}

function query(params: Record<string, unknown>): string {
  const search = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') search.set(k, String(v));
  }
  const s = search.toString();
  return s ? `?${s}` : '';
}

// ── API 関数（Step 5A 時点で backend 実装済みのもの） ──

export const getStatsSummary = () => request<StatsSummary>('/stats/summary');

export const getRecords = (params: RecordsQuery = {}) =>
  request<RecordsResponse>(`/records${query({ ...params })}`);

export const getRecord = (id: number) => request<RecordDetail>(`/records/${id}`);

export const updateRecord = (id: number, payload: Record<string, string>) =>
  request<RecordDetail>(`/records/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });

export const getDatasets = () => request<Dataset[]>('/datasets');

export const getSchema = () => request<SchemaInfo>('/schema');

export const getMapRecords = (params: MapQuery = {}) =>
  request<MapRecord[]>(`/map/records${query({ ...params })}`);

/** 現在の筛选条件で CSV を取得する（呼び出し側でダウンロードを起動する）。 */
export const exportRecordsCsv = async (
  params: RecordsQuery = {},
): Promise<Blob> => {
  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}/export/csv${query({ ...params })}`);
  } catch {
    throw new ApiError(`Cannot reach backend at ${API_BASE_URL}.`);
  }
  if (!res.ok) {
    throw new ApiError(`${res.status}: ${res.statusText}`, res.status);
  }
  return res.blob();
};

/** Dataset Package（llmap_dataset_*.zip）を導入する。
    mode: 'ask'=重複包なら duplicate を返す（既定） / 'fill_missing'=欠落写真のみ補充。
    keepOriginal: true なら原始 zip を archives/ に保管（既定は保管しない）。 */
export const importDatasetPackage = (
  file: File,
  opts: { mode?: 'ask' | 'fill_missing'; keepOriginal?: boolean } = {},
) => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('mode', opts.mode ?? 'ask');
  formData.append('keepOriginal', String(opts.keepOriginal ?? false));
  return request<ImportDatasetResult>('/datasets/import', {
    method: 'POST',
    body: formData,
  });
};

export const getStorageSummary = () =>
  request<StorageSummary>('/storage/summary');

export const storageCleanup = (dryRun: boolean) =>
  request<StorageCleanupResult>('/storage/cleanup', {
    method: 'POST',
    body: JSON.stringify({ dryRun }),
  });

/** GeoJSON（FeatureCollection）を取得する。props: minimal | full。 */
export const exportGeoJson = async (
  params: RecordsQuery = {},
  props: 'minimal' | 'full' = 'minimal',
): Promise<Blob> => {
  let res: Response;
  try {
    res = await fetch(
      `${API_BASE_URL}/export/geojson${query({ ...params, props })}`);
  } catch {
    throw new ApiError(`Cannot reach backend at ${API_BASE_URL}.`);
  }
  if (!res.ok) {
    throw new ApiError(`${res.status}: ${res.statusText}`, res.status);
  }
  return res.blob();
};

export const startPackageExport = (filters: RecordsQuery = {}) =>
  request<{ jobId: string }>('/export/package', {
    method: 'POST',
    body: JSON.stringify(filters),
  });

export const startPhotosExport = (
  filters: RecordsQuery = {},
  content: 'crop' | 'source' | 'both' = 'both',
  naming: 'signid' | 'displayid' | 'original' = 'original',
) =>
  request<{ jobId: string }>('/export/photos', {
    method: 'POST',
    body: JSON.stringify({ ...filters, content, naming }),
  });

export const getExportJob = (id: string) =>
  request<ExportJobStatus>(`/export/jobs/${id}`);

export const cancelExportJob = (id: string) =>
  request<{ ok: boolean }>(`/export/jobs/${id}/cancel`, { method: 'POST' });

/** 完了ジョブのダウンロード URL（<a href> 用）。 */
export const exportJobDownloadUrl = (id: string) =>
  `${API_BASE_URL}/export/jobs/${id}/download`;

export const getHealth = () =>
  request<{ ok: boolean; version: string }>('/health');

export const getAiStatus = () => request<AiStatus>('/ai/status');

/** バッチ AI: 対象の事前集計（AI 呼び出し・書き込みなし）。 */
export const aiPreview = (filters: RecordsQuery = {}) =>
  request<AiPreview>('/ai/preview', {
    method: 'POST',
    body: JSON.stringify(filters),
  });

export const startAiJob = (filters: RecordsQuery = {}, provider?: string) =>
  request<{ jobId: string }>('/ai/jobs', {
    method: 'POST',
    body: JSON.stringify(provider ? { ...filters, provider } : filters),
  });

/** afterSeq 以降のログだけを増分取得（-1 = 全件）。 */
export const getAiJob = (id: string, afterSeq = -1) =>
  request<AiJobStatus>(`/ai/jobs/${id}${query({ afterSeq })}`);

export const cancelAiJob = (id: string) =>
  request<{ ok: boolean }>(`/ai/jobs/${id}/cancel`, { method: 'POST' });

/** アプリ設定（導出目录・AI プロバイダ/キーなど）。 */
export const getConfig = () => request<AppConfig>('/config');

export const updateConfig = (payload: AppConfigUpdate) =>
  request<AppConfig>('/config', {
    method: 'PUT',
    body: JSON.stringify(payload),
  });

/** 写真 URL（<img src> 用）。 */
export const photoUrl = (path: string | null): string | null =>
  path ? `${API_BASE_URL}${path}` : null;
