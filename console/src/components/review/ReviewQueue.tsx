import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import LangTags from '../LangTags';
import PhotoThumb from '../database/PhotoThumb';
import StatusBadge from '../database/StatusBadge';

/** 審核队列（左列）。選択中は左に墨の縦線。 */
export default function ReviewQueue({
  items,
  selectedId,
  onSelect,
}: {
  items: RecordItem[];
  selectedId: number | null;
  onSelect: (id: number) => void;
}) {
  return (
    <div className="rv-queue">
      {items.map((r) => (
        <button
          key={r.id}
          type="button"
          className={`queue-item${r.id === selectedId ? ' selected' : ''}`}
          ref={r.id === selectedId ? (el) => el?.scrollIntoView({ block: 'nearest' }) : undefined}
          onClick={() => onSelect(r.id)}
        >
          <PhotoThumb src={photoUrl(r.thumbnailUrl)} size={52} alt={r.SignID} />
          <span className="queue-body">
            <span className="mono queue-id">{r.DisplayID || r.SignID}</span>
            <LangTags value={r.主要言語} />
            <span className="queue-meta">
              <span className="mono">{(r.採集日時 || '—').slice(5)}</span>
              <StatusBadge value={r.DataStatus} />
            </span>
          </span>
        </button>
      ))}
    </div>
  );
}
