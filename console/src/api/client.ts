// LLMap backend API client。
// base URL は .env の VITE_API_BASE_URL（既定 http://localhost:8000）。
import type {
  Dataset,
  RecordDetail,
  RecordsQuery,
  RecordsResponse,
  SchemaInfo,
  StatsSummary,
} from './types';

export const API_BASE_URL: string =
  import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';

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
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      headers: { 'Content-Type': 'application/json' },
      ...init,
    });
  } catch {
    throw new ApiError(
      `Cannot reach backend at ${API_BASE_URL}. Is it running? (uvicorn app.main:app --port 8000)`,
    );
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

export const getHealth = () =>
  request<{ ok: boolean; version: string }>('/health');

/** 写真 URL（<img src> 用）。 */
export const photoUrl = (path: string | null): string | null =>
  path ? `${API_BASE_URL}${path}` : null;
