// 審核状態の一元定義。_status（モバイル互換の legacy 字段）と
// DataStatus（Console/DB の審核字段）の対応はここ**だけ**に置く。
//
// 常規対応（アプリ側 kDataStatusMap と同一）:
//   pending        -> raw / submitted
//   ai             -> ai_drafted
//   human-reviewed -> reviewed
//   final          -> verified
//
// needs_review / rejected は Console 専用の審核状態。モバイルの旧状態体系を
// 壊さないよう DataStatus のみ書き、_status は現状のまま保持する。

/** 「待審核」とみなす DataStatus（既定队列）。 */
export const PENDING_STATUSES = ['raw', 'submitted', 'ai_drafted', 'needs_review'];

/** 队列の快速タブ。 */
export const QUEUE_TABS: { key: string; label: string; statuses: string[] }[] = [
  { key: 'pending', label: 'All pending', statuses: PENDING_STATUSES },
  { key: 'raw', label: 'Raw', statuses: ['raw'] },
  { key: 'submitted', label: 'Submitted', statuses: ['submitted'] },
  { key: 'ai_drafted', label: 'AI drafted', statuses: ['ai_drafted'] },
  { key: 'needs_review', label: 'Needs review', statuses: ['needs_review'] },
  { key: 'reviewed', label: 'Reviewed', statuses: ['reviewed'] },
  { key: 'verified', label: 'Verified', statuses: ['verified'] },
  { key: 'rejected', label: 'Rejected', statuses: ['rejected'] },
];

export type ReviewActionKey = 'reviewed' | 'verified' | 'needs_review' | 'rejected';

export interface ReviewActionDef {
  key: ReviewActionKey;
  label: string;
  /** PATCH に載せる状態字段。 */
  payload: Record<string, string>;
  /** 実行後に既定队列（pending）から消えるか。 */
  leavesQueue: boolean;
  kind: 'positive' | 'neutral' | 'negative';
}

export const REVIEW_ACTIONS: ReviewActionDef[] = [
  {
    key: 'reviewed',
    label: 'Mark as reviewed',
    payload: { _status: 'human-reviewed', DataStatus: 'reviewed' },
    leavesQueue: true,
    kind: 'positive',
  },
  {
    key: 'verified',
    label: 'Mark as verified',
    payload: { _status: 'final', DataStatus: 'verified' },
    leavesQueue: true,
    kind: 'positive',
  },
  {
    key: 'needs_review',
    label: 'Needs review',
    payload: { DataStatus: 'needs_review' }, // _status は保持（モバイル互換）
    leavesQueue: false,
    kind: 'neutral',
  },
  {
    key: 'rejected',
    label: 'Reject',
    payload: { DataStatus: 'rejected' }, // _status は保持（モバイル互換）
    leavesQueue: true,
    kind: 'negative',
  },
];
