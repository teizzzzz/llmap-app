// 画像をクリップボードへビットマップとして复制する（InDesign / Illustrator
// などのレイアウトソフトへ直接粘贴する用途）。
// ClipboardItem が広くサポートするのは image/png のみのため、JPEG は
// canvas 経由で PNG に変換してから書き込む。

export async function copyImageToClipboard(url: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const blob = await res.blob();
  const bitmap = await createImageBitmap(blob);
  try {
    const canvas = document.createElement('canvas');
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('canvas 2d context unavailable');
    ctx.drawImage(bitmap, 0, 0);
    const png: Blob = await new Promise((resolve, reject) =>
      canvas.toBlob(
        (b) => (b ? resolve(b) : reject(new Error('toBlob failed'))),
        'image/png',
      ));
    await navigator.clipboard.write([new ClipboardItem({ 'image/png': png })]);
  } finally {
    bitmap.close();
  }
}
