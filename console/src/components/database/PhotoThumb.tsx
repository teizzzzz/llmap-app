import { useEffect, useState } from 'react';

/** 写真サムネイル。src 無し / 読込失敗は placeholder を出す（白屏にしない）。 */
export default function PhotoThumb({
  src,
  size = 44,
  alt = '',
}: {
  src: string | null;
  size?: number;
  alt?: string;
}) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  if (!src || failed) {
    return (
      <div className="thumb thumb-empty" style={{ width: size, height: size }}>
        ✕
      </div>
    );
  }
  return (
    <img
      className="thumb"
      src={src}
      width={size}
      height={size}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
    />
  );
}
