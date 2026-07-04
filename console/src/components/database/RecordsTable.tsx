import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import PhotoThumb from './PhotoThumb';
import StatusBadge from './StatusBadge';

const dash = (v: string) => (v && v !== '—' ? v : '—');

/** 記録一覧テーブル。行クリックで詳情、選択行はハイライト。 */
export default function RecordsTable({
  items,
  selectedId,
  onSelect,
}: {
  items: RecordItem[];
  selectedId: number | null;
  onSelect: (id: number) => void;
}) {
  return (
    <table className="records-table">
      <thead>
        <tr>
          <th />
          <th>DisplayID</th>
          <th>主要言語</th>
          <th>補助言語</th>
          <th>地区</th>
          <th>採集日時</th>
          <th>Mode</th>
          <th>Status</th>
          <th>採集者</th>
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
            <td>{dash(r.主要言語)}</td>
            <td>{dash(r.補助言語)}</td>
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
