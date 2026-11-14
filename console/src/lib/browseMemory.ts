// 資料庫の閲覧状態（審核・地図・探索などへ行って戻っても続きから見られるように）。
// アプリを開いている間だけ保つ（module 変数）。範囲（筛选）や視図が変わっていれば使わない。

export const dbBrowse = {
  /** 保存したときの範囲＋視図（JSON）。一致するときだけ復元する。 */
  key: '',
  /** 表格のページ。 */
  tablePage: 1,
  /** 相册で読み込み済みの枚数。 */
  albumLoaded: 0,
  /** .content のスクロール位置。 */
  scroll: 0,
};

/** 相册の写真の縦横比（読込済み）。戻ったときに同じ配置を再現するため共有する。 */
export const photoRatios = new Map<number, number>();
