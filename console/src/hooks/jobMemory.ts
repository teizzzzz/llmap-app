// 実行中・直近のジョブ id を、このウィンドウの間だけ覚える（sessionStorage）。
// 導出・AI のページを離れてもジョブは backend で続いているので、戻ったときに
// 進捗（終わっていれば結果）を再表示できるようにする。backend を再起動すると
// ジョブは消えるので、取得できなければ忘れる。

const key = (slot: string) => `llmap.job.${slot}`;

export function rememberJob(slot: string, jobId: string): void {
  try { sessionStorage.setItem(key(slot), jobId); } catch { /* 覚えられなくても動く */ }
}

export function recallJob(slot: string): string | null {
  try { return sessionStorage.getItem(key(slot)); } catch { return null; }
}

export function forgetJob(slot: string): void {
  try { sessionStorage.removeItem(key(slot)); } catch { /* */ }
}
