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
  rejected: '#c0392b',
};

/** EntryMode / DataStatus / _status の小さな badge。未知値は unknown 表示。 */
export default function StatusBadge({ value }: { value: string }) {
  const v = value || 'unknown';
  const c = COLORS[v] ?? '#6f6a61';
  return (
    <span
      className="badge"
      style={{ color: c, borderColor: `${c}55`, background: `${c}14` }}
    >
      {v}
    </span>
  );
}
