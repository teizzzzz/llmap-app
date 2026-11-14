import { photoUrl } from '../../api/client';
import type { RecordItem } from '../../api/types';
import PhotoThumb from '../database/PhotoThumb';

/** 審核队列（左列）: 写真だけを並べる（編号・時刻・状態は右の字段欄と上の帯で分かる）。
    選択中は墨の枠。名前は tooltip に残す。 */
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
          title={r.DisplayID || r.SignID}
          aria-label={r.DisplayID || r.SignID}
        >
          <PhotoThumb src={photoUrl(r.thumbnailUrl)} size={96} alt="" />
        </button>
      ))}
    </div>
  );
}
