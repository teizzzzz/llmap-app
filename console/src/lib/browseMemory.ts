// 資料庫の閲覧状態（審核・主题・関係画布などへ行って戻っても続きから見られるように）。
// アプリを開いている間だけ保つ（module 変数）。鍵＝範囲（筛选＋記録集合）＋視図。
// 関連・主题へ入って「返回」したときも元の範囲の位置へ戻れるよう、範囲ごとに覚える。

export interface BrowseState {
  /** 表格のページ。 */
  tablePage: number;
  /** 相册で読み込み済みの枚数。 */
  albumLoaded: number;
  /** .content のスクロール位置。 */
  scroll: number;
}

const MAX = 12;
const states = new Map<string, BrowseState>();

export function browseState(key: string): BrowseState | undefined {
  return states.get(key);
}

export function saveBrowse(key: string, patch: Partial<BrowseState>): void {
  const prev = states.get(key) ?? { tablePage: 1, albumLoaded: 0, scroll: 0 };
  states.delete(key); // 新しいものを後ろへ（古いものから捨てる）
  states.set(key, { ...prev, ...patch });
  while (states.size > MAX) states.delete(states.keys().next().value as string);
}

/** 資料庫の今の視図（「返回」の戻り先や旧ルートの互換で使う）。 */
export const dbView = { current: '' };

/** 相册の写真の縦横比（読込済み）。戻ったときに同じ配置を再現するため共有する。 */
export const photoRatios = new Map<number, number>();

/** 地図の視図: 範囲ごとの中心とズーム（同じ範囲へ戻ったら前の位置から）。 */
export const mapViews = new Map<string, { center: [number, number]; zoom: number }>();
