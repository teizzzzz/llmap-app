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
  /** 相册カード用の実測値（Step 17。backend が集計して返す） */
  liveRecordCount?: number;
  photoBytes?: number;
  coverPhoto?: string | null;
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
  /** 選択中のプロバイダ（claude | gemini） */
  provider: string;
  /** API キー設定済みのプロバイダ一覧 */
  providers: string[];
  message: string;
  /** プロバイダごとの選択中モデル */
  models: Record<string, string>;
  /** プロバイダごとの選択可能モデル一覧（設定 UI 用） */
  modelOptions: Record<string, string[]>;
}

/** POST /ai/preview — バッチ対象の事前集計（AI 呼び出しなし） */
export interface AiPreview {
  total: number;
  withPhoto: number;
  withoutPhoto: number;
  missingPhotoFile: number;
  byStatus: Record<string, number>;
}

/** バッチ AI の実時ログ 1 行（文言は Console 側で i18n） */
export interface AiLogEntry {
  seq: number;
  time: string;
  event: 'jobStart' | 'changed' | 'unchanged' | 'skipped' | 'error'
    | 'done' | 'abort' | 'cancelled';
  signId: string;
  data: Record<string, string | number>;
}

/** GET /ai/jobs/{id} — バッチ AI ジョブの進捗・結果 */
export interface AiJobStatus {
  id: string;
  kind: 'ai';
  provider: string;
  model: string;
  status: 'running' | 'done' | 'error' | 'cancelled';
  done: number;
  total: number;
  error: string;
  errors: { signId: string; message: string }[];
  /** afterSeq より後の実時ログ（増分） */
  logs: AiLogEntry[];
  lastSeq: number;
  report: {
    recordCount?: number;
    changedRecords?: number;
    changedFieldTotal?: number;
    unchangedRecords?: number;
    skippedNoPhoto?: number;
    errorCount?: number;
    provider?: string;
  };
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

export interface StorageResetResult {
  ok: boolean;
  deletedRecords: number;
  deletedDatasets: number;
  deletedPhotos: number;
  freedBytes: number;
}

/** GET /schema — フォーム選択肢（enums）・複数選択字段・状態値 */
export interface SchemaInfo {
  csv_header: string[];
  status_values: string[];
  enums: Record<string, string[]>;
  ai_fields: string[];
  language_colors: Record<string, string>;
  multi_fields: string[];
  /** 系統字段（研究字段の派生用）。旧 backend では未配信のため optional。 */
  system_fields?: string[];
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
  /** データセット多选（導出等）。datasetId より優先。GET では "1,3" に直列化。 */
  datasetIds?: number[];
  /** 研究字段（字段表）での筛选: 字段名 → 値。GET では JSON 文字列に直列化。 */
  fields?: Record<string, string>;
}

/** 導出ジョブ（Dataset Package / 写真 ZIP）の進捗（Step 16） */
export interface ExportJobStatus {
  id: string;
  kind: 'package' | 'photos';
  status: 'running' | 'done' | 'error' | 'cancelled';
  done: number;
  total: number;
  fileName: string;
  /** 生成先のフルパス（done 時のみ。導出目录設定の可視化用） */
  path: string;
  sizeBytes: number;
  error: string;
  report: Record<string, number>;
}

/** GET/PUT /config の応答（settings.json）。 */
export interface AppConfig {
  /** 設定済みの導出目录（未設定は null = 既定 data_dir/exports） */
  exportDir: string | null;
  /** フォールバック解決後の実効導出先 */
  effectiveExportDir: string;
  defaultExportDir: string;
  /** バッチ AI のプロバイダ（claude | gemini | null = 既定） */
  aiProvider: string | null;
  /** キーは GET で返らない（CORS 全開のため）— 有無とヒントのみ */
  claudeApiKeySet: boolean;
  claudeApiKeyHint: string;
  geminiApiKeySet: boolean;
  geminiApiKeyHint: string;
  /** 選択中のモデル（未設定は既定値で返る） */
  claudeModel: string;
  geminiModel: string;
}

/** PUT /config の入力（部分更新。null でそのキーを既定に戻す/消す） */
export interface AppConfigUpdate {
  exportDir?: string | null;
  aiProvider?: string | null;
  claudeApiKey?: string | null;
  geminiApiKey?: string | null;
  claudeModel?: string | null;
  geminiModel?: string | null;
}
