import { useTranslation } from 'react-i18next';

const COLORS: Record<string, string> = {
  // EntryMode
  quick: '#b8860b',
  standard: '#2563eb',
  research: '#7c3aed',
  // DataStatus
  raw: '#6f6a61',
  submitted: '#2563eb',
  ai_drafted: '#b8860b',
  reviewed: '#1e9e6a',
  verified: '#0f766e',
  needs_review: '#d97706',
  rejected: '#c0392b',
  // _status (legacy)
  pending: '#6f6a61',
  ai: '#b8860b',
  'human-reviewed': '#1e9e6a',
  final: '#0f766e',
};

/** EntryMode / DataStatus / _status の小さな badge。
    表示ラベルのみ翻訳し、内部値・色分けキーはそのまま。未知値は原文表示。 */
export default function StatusBadge({ value }: { value: string }) {
  const { t } = useTranslation();
  const v = value || 'unknown';
  const c = COLORS[v] ?? '#6f6a61';
  return (
    <span
      className="badge"
      style={{ color: c, borderColor: `${c}55`, background: `${c}14` }}
    >
      {t(`status.${v}`, { defaultValue: v })}
    </span>
  );
}
