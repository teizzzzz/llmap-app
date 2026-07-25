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

/** 队列の快速タブ。labelKey は i18n キー（key / statuses は内部値のまま）。 */
export const QUEUE_TABS: { key: string; labelKey: string; statuses: string[] }[] = [
  { key: 'pending', labelKey: 'review.tabs.pending', statuses: PENDING_STATUSES },
  { key: 'raw', labelKey: 'review.tabs.raw', statuses: ['raw'] },
  { key: 'submitted', labelKey: 'review.tabs.submitted', statuses: ['submitted'] },
  { key: 'ai_drafted', labelKey: 'review.tabs.ai_drafted', statuses: ['ai_drafted'] },
  { key: 'needs_review', labelKey: 'review.tabs.needs_review', statuses: ['needs_review'] },
  { key: 'reviewed', labelKey: 'review.tabs.reviewed', statuses: ['reviewed'] },
  { key: 'verified', labelKey: 'review.tabs.verified', statuses: ['verified'] },
  { key: 'rejected', labelKey: 'review.tabs.rejected', statuses: ['rejected'] },
];

export type ReviewActionKey = 'reviewed' | 'verified' | 'needs_review' | 'rejected';

export interface ReviewActionDef {
  key: ReviewActionKey;
  /** ボタン表示の i18n キー（payload の状態値は翻訳しない）。 */
  labelKey: string;
  /** PATCH に載せる状態字段。 */
  payload: Record<string, string>;
  /** 実行後に既定队列（pending）から消えるか。 */
  leavesQueue: boolean;
  kind: 'positive' | 'neutral' | 'negative';
}

export const REVIEW_ACTIONS: ReviewActionDef[] = [
  {
    key: 'reviewed',
    labelKey: 'review.actions.reviewed',
    payload: { _status: 'human-reviewed', DataStatus: 'reviewed' },
    leavesQueue: true,
    kind: 'positive',
  },
  {
    key: 'verified',
    labelKey: 'review.actions.verified',
    payload: { _status: 'final', DataStatus: 'verified' },
    leavesQueue: true,
    kind: 'positive',
  },
  {
    key: 'needs_review',
    labelKey: 'review.actions.needs_review',
    payload: { DataStatus: 'needs_review' }, // _status は原則保持（モバイル互換）
    leavesQueue: false,
    kind: 'neutral',
  },
  {
    key: 'rejected',
    labelKey: 'review.actions.rejected',
    payload: { DataStatus: 'rejected' }, // _status は原則保持（モバイル互換）
    leavesQueue: true,
    kind: 'negative',
  },
];

/** アクションの PATCH payload を現在の _status を考慮して組み立てる。
    needs_review / rejected を「確定済み」（human-reviewed / final）の記録に
    適用する場合は _status を pending に降格させる — さもないと
    「final なのに needs_review」というモバイル/Console 間の矛盾状態になる。
    pending / ai の場合は従来どおり _status を保持する。 */
export function actionPayload(
  action: ReviewActionDef,
  currentStatus: string,
): Record<string, string> {
  const demote =
    (action.key === 'needs_review' || action.key === 'rejected') &&
    (currentStatus === 'human-reviewed' || currentStatus === 'final');
  return demote ? { ...action.payload, _status: 'pending' } : action.payload;
}
