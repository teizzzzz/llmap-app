# -*- coding: utf-8 -*-
"""LLMap アプリアイコンの生成（視覚規範 v1: 紙・墨・荧光、網点、裁切線）。

「LL」は矩形だけで組める字形なので、フォントに依存せず幾何で描く。
大きいサイズ（64px 以上）は網点の灰色块・虚線円・補助線・十字裁切線まで入れ、
小さいサイズ（48px 以下）は細線が潰れるため字形＋荧光の帯だけの簡略版にする。

出力: icon-1024.png（原図）/ icon.png（128）/ icon.ico / icon.icns
Run: python make_icon.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).resolve().parent
PAPER = (237, 236, 231)
INK = (18, 18, 18)
HALFTONE = (167, 165, 160)
LIME = (200, 240, 60)
# 乗算で紙の上がちょうど LIME になるよう紙色で割り戻した版の色
LIME_PLATE = tuple(min(255, round(c * 255 / p)) for c, p in zip(LIME, PAPER))
SS = 4  # スーパーサンプリング倍率（縮小時のアンチエイリアス用）


def rounded_mask(size, inset, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [inset, inset, size - 1 - inset, size - 1 - inset], radius=radius, fill=255)
    return m


def letters(d, s, x0, y0, stem, foot, height, gap):
    """太い「LL」。x0,y0 = 左上、stem = 縦画の太さ、foot = 横画の長さ。"""
    for k in range(2):
        x = x0 + k * (foot + gap)
        d.rectangle([x * s, y0 * s, (x + stem) * s, (y0 + height) * s], fill=INK)
        d.rectangle([x * s, (y0 + height - stem) * s, (x + foot) * s, (y0 + height) * s], fill=INK)


def render_full(px=1024):
    """64px 以上用。1024 座標系で描いて縮小する。"""
    s = SS * px / 1024
    W = int(1024 * s)
    base = Image.new('RGB', (W, W), PAPER)
    d = ImageDraw.Draw(base)

    # 網点の灰色块（印刷の粒子感）
    bx0, by0, bx1, by1 = 150, 150, 430, 820
    cell = 22
    for row, gy in enumerate(range(by0, by1, cell)):
        shift = cell / 2 if row % 2 else 0  # 千鳥 = 45° の網点スクリーン
        for gx in range(bx0, bx1 - int(shift), cell):
            r = 7.5
            cx0, cy0 = gx + shift + cell / 2, gy + cell / 2
            d.ellipse([(cx0 - r) * s, (cy0 - r) * s, (cx0 + r) * s, (cy0 + r) * s], fill=HALFTONE)

    # 虚線の円
    cx, cy, R = 640, 400, 250
    for i in range(0, 360, 6):
        a0, a1 = math.radians(i), math.radians(i + 3)
        d.line([((cx + R * math.cos(a0)) * s, (cy + R * math.sin(a0)) * s),
                ((cx + R * math.cos(a1)) * s, (cy + R * math.sin(a1)) * s)],
               fill=INK, width=max(1, int(4 * s)))

    # 字形
    letters(d, s, x0=196, y0=250, stem=150, foot=300, height=530, gap=36)

    # 補助線
    lw = max(1, int(4 * s))
    d.line([(560 * s, 96 * s), (560 * s, 930 * s)], fill=INK, width=lw)
    d.line([(96 * s, 648 * s), (930 * s, 648 * s)], fill=INK, width=lw)

    # 十字裁切線
    for (x, y) in [(150, 150), (874, 874)]:
        d.line([((x - 40) * s, y * s), ((x + 40) * s, y * s)], fill=INK, width=lw)
        d.line([(x * s, (y - 40) * s), (x * s, (y + 40) * s)], fill=INK, width=lw)

    # 荧光の帯（乗算 = 透明版を重ねた見え方。墨の上では墨のまま）
    lime = Image.new('RGB', (W, W), (255, 255, 255))
    ld = ImageDraw.Draw(lime)
    ld.rectangle([450 * s, 150 * s, 530 * s, 560 * s], fill=LIME_PLATE)
    ld.rectangle([720 * s, 560 * s, 800 * s, 900 * s], fill=LIME_PLATE)
    art = ImageChops.multiply(base, lime)

    out = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    out.paste(art, (0, 0), rounded_mask(W, int(64 * s), int(150 * s)))
    return out.resize((px, px), Image.LANCZOS)


def render_small(px):
    """48px 以下用。字形を大きく、細線なし、角丸を浅く・余白なし。"""
    s = SS * px / 1024
    W = int(1024 * s)
    base = Image.new('RGB', (W, W), PAPER)
    d = ImageDraw.Draw(base)
    d.rectangle([120 * s, 110 * s, 420 * s, 910 * s], fill=(204, 202, 196))
    letters(d, s, x0=150, y0=170, stem=200, foot=350, height=700, gap=24)
    lime = Image.new('RGB', (W, W), (255, 255, 255))
    ImageDraw.Draw(lime).rectangle([500 * s, 60 * s, 610 * s, 600 * s], fill=LIME_PLATE)
    art = ImageChops.multiply(base, lime)
    out = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    out.paste(art, (0, 0), rounded_mask(W, int(16 * s), int(110 * s)))
    return out.resize((px, px), Image.LANCZOS)


def main():
    master = render_full(1024)
    master.save(HERE / 'icon-1024.png', optimize=True)
    render_full(128).save(HERE / 'icon.png', optimize=True)

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    imgs = [render_small(n) if n <= 48 else render_full(n) for n in ico_sizes]
    imgs[-1].save(HERE / 'icon.ico', sizes=[(n, n) for n in ico_sizes], append_images=imgs[:-1])

    icns_sizes = [16, 32, 64, 128, 256, 512, 1024]
    icns = [render_small(n) if n <= 48 else render_full(n) for n in icns_sizes]
    icns[-1].save(HERE / 'icon.icns', append_images=icns[:-1])

    # 確認用の一覧（ファイルには残さない）
    sheet = Image.new('RGBA', (sum(ico_sizes) + 20 * len(ico_sizes) + 280, 300), (237, 236, 231, 255))
    x = 10
    for im in imgs + [render_full(256)]:
        sheet.paste(im, (x, 10), im)
        x += im.width + 20
    return sheet


if __name__ == '__main__':
    import sys
    sheet = main()
    if len(sys.argv) > 1:
        sheet.save(sys.argv[1])
    print('ok')
