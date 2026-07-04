// Backend (FastAPI v0.2.0) の応答型。docs/data-contract.md / records_api.py に対応。

/** GET /stats/summary */
export interface StatsSummary {
  recordCount: number;
  datasetCount: number;
  photoCount: number;
  sourcePhotoCount: number;
  missingPhotoCount: number;
  missingSourcePhotoCount: number;
  entryModeCounts: Record<string, number>;
  dataStatusCounts: Record<string, number>;
  mainLanguageCounts: Record<string, number>;
  areaCounts: Record<string, number>;
  collectorCounts: Record<string, number>;
}

/** GET /records の1件（キーは CSV 正準キー） */
export interface RecordItem {
  id: number;
  SignID: string;
  CaptureID: string;
  DisplayID: string;
  EntryMode: string;
  DataStatus: string;
  _status: string;
  主要言語: string;
  補助言語: string;
  地区コード: string;
  採集者ID: string;
  採集日時: string;
  緯度: number | null;
  経度: number | null;
  写真ファイル名: string;
  元写真ファイル名: string;
  thumbnailUrl: string | null;
}

/** GET /records */
export interface RecordsResponse {
  items: RecordItem[];
  page: number;
  pageSize: number;
  total: number;
}

/** GET /records/{id} — 一覧項目＋全字段＋写真URL＋dataset */
export interface RecordDetail extends RecordItem {
  data: Record<string, string>;
  photoUrl: string | null;
  sourcePhotoUrl: string | null;
  dataset: Dataset | null;
  createdAt: string;
  updatedAt: string;
}

/** GET /datasets */
export interface Dataset {
  id: number;
  name: string;
  imported_at: string;
  format_version: string;
  app_version: string;
  schema_version: string;
  record_count: number;
  photo_count: number;
  source_photo_count: number;
  normalized_legacy_record_count: number;
  missing_photo_count: number;
  missing_source_photo_count: number;
}

/** GET /records の筛选パラメータ */
export interface RecordsQuery {
  page?: number;
  pageSize?: number;
  q?: string;
  mainLanguage?: string;
  areaCode?: string;
  collectorId?: string;
  entryMode?: string;
  dataStatus?: string;
  status?: string;
  dateFrom?: string;
  dateTo?: string;
  hasGps?: boolean;
  hasPhoto?: boolean;
  hasSourcePhoto?: boolean;
  datasetId?: number;
}
