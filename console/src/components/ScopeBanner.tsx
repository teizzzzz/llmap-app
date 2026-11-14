import { useTranslation } from 'react-i18next';
import type { Dataset, RecordsQuery } from '../api/types';
import { filterChips } from './database/RecordsFilters';

/** 操作の対象範囲を明示する帯（資料庫 → 審核 / AI / 導出 の引き継ぎ用）。
    「どの記録に効くか」を条件 chip と件数で示し、全件へ戻す操作を添える。
    filters が空なら「全部の記録」と表示する。 */
export default function ScopeBanner({
  filters,
  datasets,
  count,
  countLabel,
  onReset,
  resetLabel,
}: {
  filters: RecordsQuery;
  datasets: Dataset[];
  /** この範囲の件数（未取得なら null）。 */
  count: number | null;
  /** 件数の説明（例: 「待审核 12 条」）。未指定なら「N 条」。 */
  countLabel?: string;
  onReset?: () => void;
  resetLabel?: string;
}) {
  const { t } = useTranslation();
  const chips = filterChips(filters, datasets, t);
  return (
    <div className="scope-banner">
      <span className="scope-k">{t('scope.label')}</span>
      {chips.length === 0
        ? <span className="scope-v">{t('scope.all')}</span>
        : filters.ids?.length
          // 手動選択は筛选とは別物 —— 「選んだ記録」とだけ示す。
          ? <span className="scope-v"><span className="scope-chip">{t('scope.selectedN', { n: filters.ids.length })}</span></span>
          : (
            <span className="scope-v">
              <span className="scope-src">{t('scope.fromDatabase')}</span>
              {chips.map((c) => <span key={c.key} className="scope-chip">{c.label}</span>)}
            </span>
          )}
      <span className="spacer" />
      <span className="scope-count">
        {countLabel ?? (count != null ? t('scope.count', { n: count }) : '—')}
      </span>
      {onReset && chips.length > 0 && (
        <button type="button" className="btn ghost" onClick={onReset}>
          {resetLabel ?? t('scope.reset')}
        </button>
      )}
    </div>
  );
}
