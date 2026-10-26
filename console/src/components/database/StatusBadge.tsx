import { useTranslation } from 'react-i18next';

// 状態値 → 見た目の種類（色は CSS 側。荧光は「要対応」の needs_review だけ）。
const KIND: Record<string, string> = {
  // DataStatus
  reviewed: 'outline',
  verified: 'solid',
  needs_review: 'lime',
  rejected: 'danger',
  ai_drafted: 'dashed',
  raw: 'faint',
  submitted: 'faint',
  // _status (legacy)
  'human-reviewed': 'outline',
  final: 'solid',
  ai: 'dashed',
  pending: 'faint',
  // EntryMode
  quick: 'mode',
  standard: 'mode',
  research: 'mode',
};

/** EntryMode / DataStatus / _status の小さな badge。
    表示ラベルのみ翻訳し、内部値はそのまま。未知値は原文表示。 */
export default function StatusBadge({ value }: { value: string }) {
  const { t } = useTranslation();
  const v = value || 'unknown';
  return (
    <span className={`badge ${KIND[v] ?? 'faint'}`}>
      {t(`status.${v}`, { defaultValue: v })}
    </span>
  );
}
