import type { SchemaInfo } from '../api/types';

// v6 定義表（2026-07-24）に存在しない旧字段。UI から隠す（ユーザー決定
// 2026-07-25）。CSV 列とデータは互換のため保持 — 完全削除は SchemaVersion 1.7 で。
export const HIDDEN_LEGACY_FIELDS = ['名称', '文字体系', '空間階層', '設置主体'];

// 旧 backend（system_fields 未配信）向けのフォールバック（backend/app/schema.py
// SYSTEM_FIELDS の写し）。桌面版は backend と同梱なので通常は使われない。
const SYSTEM_FIELDS_FALLBACK = [
  'SignID', '_status',
  'CaptureID', 'DisplayID', '採集者ID', '地区コード', 'LocalSeq',
  'CropSuffix', 'CropRect',
  '写真ID', '写真ファイル名', '元写真ファイル名', '全景写真ファイル名',
  '緯度', '経度', '採集日時',
  'EntryMode', 'DataStatus', 'SchemaVersion', 'AppVersion',
];

// v6 の区分（見出しの割当のみ）。字段リスト自体は schema から派生するため、
// ここに無い新字段が将来増えても「other」グループに自動で現れる — 消えない。
const GROUP_B = ['文字性', '主要言語', '補助言語', '装飾の言語', '多言語関係'];
const GROUP_C = ['担体類型', '放置位置', '時間性', '可読性', '重ね書き'];
const GROUP_D = ['ディスコース類型', '製作品質', '備考'];

export interface FieldGroup {
  key: 'B' | 'C' | 'D' | 'other';
  fields: string[];
}

/** v6 の研究字段 = CSV 表頭 − 系統字段 − 旧字段。schema が唯一の正。 */
export function researchFields(schema: SchemaInfo | null): string[] {
  if (!schema) return [];
  const system = new Set(schema.system_fields ?? SYSTEM_FIELDS_FALLBACK);
  return schema.csv_header.filter(
    (f) => !system.has(f) && !HIDDEN_LEGACY_FIELDS.includes(f),
  );
}

/** v6 の区分（B 言語 / C 物質·状態 / D 社会·機能）でグループ化して返す。 */
export function groupedResearchFields(schema: SchemaInfo | null): FieldGroup[] {
  const fields = researchFields(schema);
  const known = new Set([...GROUP_B, ...GROUP_C, ...GROUP_D]);
  const pick = (order: string[]) => order.filter((f) => fields.includes(f));
  const groups: FieldGroup[] = [
    { key: 'B', fields: pick(GROUP_B) },
    { key: 'C', fields: pick(GROUP_C) },
    { key: 'D', fields: pick(GROUP_D) },
    { key: 'other', fields: fields.filter((f) => !known.has(f)) },
  ];
  return groups.filter((g) => g.fields.length > 0);
}
