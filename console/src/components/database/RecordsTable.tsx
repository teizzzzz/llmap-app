import { useTranslation } from 'react-i18next';
import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import { multiEnumLabel } from '../../lib/enumLabels';
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
          <th />
          <th>DisplayID</th>
          <th>{t('fields.主要言語')}</th>
          <th>{t('fields.補助言語')}</th>
          <th>{t('table.area')}</th>
          <th>{t('fields.採集日時')}</th>
          <th>{t('table.mode')}</th>
          <th>{t('table.status')}</th>
          <th>{t('table.collector')}</th>
          <th>GPS</th>
        </tr>
      </thead>
      <tbody>
        {items.map((r) => (
          <tr
            key={r.id}
            className={r.id === selectedId ? 'selected' : ''}
            onClick={() => onSelect(r.id)}
          >
            <td>
              <PhotoThumb src={photoUrl(r.thumbnailUrl)} size={40} alt={r.SignID} />
            </td>
            <td className="mono">{r.DisplayID || r.SignID}</td>
            <td>{multiEnumLabel(t, dash(r.主要言語))}</td>
            <td>{multiEnumLabel(t, dash(r.補助言語))}</td>
            <td>{dash(r.地区コード)}</td>
            <td className="mono">{dash(r.採集日時)}</td>
            <td><StatusBadge value={r.EntryMode} /></td>
            <td><StatusBadge value={r.DataStatus} /></td>
            <td className="mono">{dash(r.採集者ID)}</td>
            <td>{r.緯度 != null && r.経度 != null ? '✓' : '—'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
