import { useTranslation } from 'react-i18next';
import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import { multiEnumLabel } from '../../lib/enumLabels';
import PhotoThumb from '../database/PhotoThumb';
import StatusBadge from '../database/StatusBadge';

/** 審核队列（左列）。1件 = カード。選択中はハイライト。 */
export default function ReviewQueue({
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
    <div className="review-queue">
      {items.map((r) => (
        <button
          key={r.id}
          type="button"
          className={`queue-card${r.id === selectedId ? ' selected' : ''}`}
          onClick={() => onSelect(r.id)}
        >
          <PhotoThumb src={photoUrl(r.thumbnailUrl)} size={52} alt={r.SignID} />
          <div className="queue-card-body">
            <div className="queue-card-title mono">{r.DisplayID || r.SignID}</div>
            <div className="queue-card-sub">
              {r.主要言語 ? multiEnumLabel(t, r.主要言語) : '—'} · {r.地区コード || '—'}
            </div>
            <div className="queue-card-sub mono">{r.採集日時 || '—'}</div>
            <div className="queue-card-badges">
              <StatusBadge value={r.EntryMode} />
              <StatusBadge value={r.DataStatus} />
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}
