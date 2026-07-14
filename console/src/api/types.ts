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

/** GET /map/records の1件（GPS を持つ記録のみ・軽量） */
export interface MapRecord {
  id: number;
  signId: string;
  displayId: string;
  lat: number;
  lng: number;
  mainLanguage: string;
  dataStatus: string;
  entryMode: string;
  photoUrl: string | null;
}

/** GET /map/records の筛选（/records と同じ命名） */
export interface MapQuery {
  mainLanguage?: string;
  areaCode?: string;
  entryMode?: string;
  dataStatus?: string;
  datasetId?: number;
}

/** GET /ai/status — AI バッチ処理の設定状態（scaffold） */
export interface AiStatus {
  enabled: boolean;
  providers: string[];
  message: string;
}

/** POST /datasets/import の導入レポート */
export interface ImportDatasetResult {
  /** imported=新規導入 / duplicate=同一包を検出（未導入） / filled=欠落写真の補充 */
  status: 'imported' | 'duplicate' | 'filled';
  datasetId?: number;
  recordCount?: number;
  importedRecordCount?: number;
  skippedRecordCount?: number;
  photoCount?: number;
  sourcePhotoCount?: number;
  reusedPhotoCount?: number;
  missingPhotoCount?: number;
  missingSourcePhotoCount?: number;
  duplicateSignIds?: string[];
  warnings?: string[];
  archivedTo?: string | null;
  // status=duplicate のとき
  existingDatasetId?: number;
  existingDatasetName?: string;
  existingImportedAt?: string;
  // status=filled のとき
  restoredPhotoCount?: number;
  stillMissingCount?: number;
}

/** GET /storage/summary — データ目录の使用状況（Step 15） */
export interface StorageSummary {
  dataDir: string;
  categories: {
    photos: number;
    sourcePhotos: number;
    database: number;
    imports: number;
    archives: number;
    exports: number;
    tmp: number;
  };
  diskTotal: number;
  diskFree: number;
  reclaimableBytes: number;
  reclaimableEntries: string[];
}

/** POST /storage/cleanup の結果 */
export interface StorageCleanupResult {
  ok: boolean;
  dryRun: boolean;
  deleted: number;
  reclaimableBytes: number;
  freedBytes?: number;
  entries?: string[];
  missingPhotos?: string[];
  missingPhotoCount: number;
  message?: string;
}

/** GET /schema — フォーム選択肢（enums）・複数選択字段・状態値 */
export interface SchemaInfo {
  csv_header: string[];
  status_values: string[];
  enums: Record<string, string[]>;
  ai_fields: string[];
  language_colors: Record<string, string>;
  multi_fields: string[];
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
