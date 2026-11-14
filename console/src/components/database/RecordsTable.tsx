import { useTranslation } from 'react-i18next';
import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import LangTags from '../LangTags';
import PhotoThumb from './PhotoThumb';
import StatusBadge from './StatusBadge';

const dash = (v: string) => (v && v !== '—' ? v : '—');

/** 記録一覧テーブル。行クリックで詳情（開いている行はハイライト）。
    先頭の checkbox は批量操作用の選択で、詳情とは別の操作。
    列見出しは表示のみ翻訳（データの字段キー・値はそのまま）。 */
export default function RecordsTable({
  items,
  selectedId,
  onSelect,
  checked,
  onToggleCheck,
  onToggleAll,
}: {
  items: RecordItem[];
  selectedId: number | null;
  onSelect: (id: number) => void;
  checked: number[];
  onToggleCheck: (id: number) => void;
  /** このページの行をまとめて選択/解除。 */
  onToggleAll: (ids: number[], on: boolean) => void;
}) {
  const { t } = useTranslation();
  const pageIds = items.map((r) => r.id);
  const allOn = pageIds.length > 0 && pageIds.every((id) => checked.includes(id));
  return (
    <table className="records-table">
      <thead>
        <tr>
          <th className="col-check">
            <input type="checkbox" checked={allOn} aria-label={t('database.selectPage')}
              title={t('database.selectPage')}
              onChange={() => onToggleAll(pageIds, !allOn)} />
          </th>
          <th className="col-thumb">{t('table.photo')}</th>
          <th>ID</th>
          <th>{t('fields.主要言語')}</th>
          <th>{t('fields.補助言語')}</th>
          <th>{t('table.area')}</th>
          <th>{t('fields.採集日時')}</th>
          <th>{t('table.collector')}</th>
          <th>{t('table.status')}</th>
        </tr>
      </thead>
      <tbody>
        {items.map((r) => (
          <tr
            key={r.id}
            className={`${r.id === selectedId ? 'selected' : ''}${checked.includes(r.id) ? ' checked' : ''}`}
            onClick={() => onSelect(r.id)}
          >
            <td className="col-check" onClick={(e) => e.stopPropagation()}>
              <input type="checkbox" checked={checked.includes(r.id)}
                aria-label={t('database.selectRecord', { id: r.DisplayID || r.SignID })}
                onChange={() => onToggleCheck(r.id)} />
            </td>
            <td className="col-thumb">
              <PhotoThumb src={photoUrl(r.thumbnailUrl)} size={44} alt={r.SignID} />
            </td>
            <td className="mono">{r.DisplayID || r.SignID}</td>
            <td><LangTags value={r.主要言語} /></td>
            <td><LangTags value={r.補助言語} /></td>
            <td>{dash(r.地区コード)}</td>
            <td className="mono dim">{dash(r.採集日時)}</td>
            <td className="mono dim">{dash(r.採集者ID)}</td>
            <td><StatusBadge value={r.DataStatus} /></td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
