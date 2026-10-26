import { useTranslation } from 'react-i18next';
import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import LangTags from '../LangTags';
import PhotoThumb from './PhotoThumb';
import StatusBadge from './StatusBadge';

const dash = (v: string) => (v && v !== '—' ? v : '—');

/** 記録一覧テーブル。行クリックで詳情、選択行はハイライト。
    列見出しは表示のみ翻訳（データの字段キー・値はそのまま）。 */
export default function RecordsTable({
  items,
  selectedId,
  onSelect,
}: {
  items: RecordItem[];
  selectedId: number | null;
  onSelect: (id: number) => void;
}) {
  const { t } = useTranslation();
  return (
    <table className="records-table">
      <thead>
        <tr>
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
            className={r.id === selectedId ? 'selected' : ''}
            onClick={() => onSelect(r.id)}
          >
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
