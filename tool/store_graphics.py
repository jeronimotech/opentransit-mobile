#!/usr/bin/env python3
"""Generate the two Play Store graphics that no screenshot run produces.

    tool/store_graphics.py              # writes both into docs/store/play/

Play requires an app icon and a feature graphic before it will publish a listing, and neither comes
out of `tool/store_shots_android.sh`. Both are derived from `assets/icon/icon.png`, so the store and
the launcher never drift apart: change the app icon and re-run this.

**Icon, 512×512.** The source has its own rounded corners with transparent pixels outside them. Play
applies its own mask, so handing it that art would round an already-rounded shape and leave the
corners see-through. This fills the square with the icon's own background colour and lets Play do the
rounding, and saves without an alpha channel.

**Feature graphic, 1024×500.** Deliberately wordmark-only: no tagline, so one file serves all seven
listing languages instead of seven files that drift. Play crops this on some surfaces and may draw a
play button over the middle of it, so the artwork is a centred group with wide margins and nothing
load-bearing at the edges.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFont
except ImportError:
    sys.exit("needs Pillow: python3 -m pip install Pillow")

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon" / "icon.png"
OUT = ROOT / "docs" / "store" / "play"

ICON_PX = 512
FEATURE = (1024, 500)
WORDMARK = "opentransit"

# The lowercase wordmark wants a geometric face; Futura is the one on every Mac that reads as
# designed rather than as a default. Helvetica is the fallback, and both are checked at run time
# because a missing font would otherwise render as invisible boxes.
# The index matters: a .ttc holds several faces and the italic one sits right next to the upright,
# so getting it wrong silently slants the wordmark.
FONT_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Futura.ttc", 0),    # Futura Medium
    ("/System/Library/Fonts/Helvetica.ttc", 1),              # Helvetica Bold
    ("/System/Library/Fonts/SFNS.ttf", 0),
]


def brand_colour(im: Image.Image) -> tuple[int, int, int]:
    """The icon's own background, read from inside the shape rather than hard-coded."""
    w, h = im.size
    px = im.convert("RGBA").getpixel((w // 2, int(h * 0.08)))
    if px[3] < 255:
        sys.exit("the sample point is transparent; the icon art has moved")
    return px[:3]


def _bright(v: int) -> int:
    return 255 if v > 200 else 0


def glyph_mask(im: Image.Image) -> Image.Image:
    """The white artwork, as a mask. Lets the banner draw it in white at any size without dragging
    the icon's background along with it."""
    r, g, b, a = im.convert("RGBA").split()
    near_white = r.point(_bright)
    for ch in (g, b):
        near_white = ImageChops.multiply(near_white, ch.point(_bright))
    return ImageChops.multiply(near_white, a)


def trim(mask: Image.Image) -> Image.Image:
    box = mask.getbbox()
    return mask.crop(box) if box else mask


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path, index in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    sys.exit("no usable font found; the wordmark would not render")


def make_icon(src: Image.Image, colour: tuple[int, int, int]) -> Image.Image:
    canvas = Image.new("RGB", src.size, colour)
    canvas.paste(src.convert("RGBA"), (0, 0), src.convert("RGBA"))
    return canvas.resize((ICON_PX, ICON_PX), Image.LANCZOS)


def make_feature(src: Image.Image, colour: tuple[int, int, int]) -> Image.Image:
    w, h = FEATURE
    banner = Image.new("RGB", FEATURE, colour)
    draw = ImageDraw.Draw(banner)

    mark = trim(glyph_mask(src))
    mark_h = 232
    mark_w = round(mark.width * mark_h / mark.height)
    mark = mark.resize((mark_w, mark_h), Image.LANCZOS)

    font = load_font(118)
    text_w = draw.textlength(WORDMARK, font=font)
    gap = 56

    # One centred group, because Play crops this graphic differently on different surfaces.
    total = mark_w + gap + text_w
    x = (w - total) / 2
    banner.paste((255, 255, 255), (round(x), round((h - mark_h) / 2)), mark)

    box = draw.textbbox((0, 0), WORDMARK, font=font)
    draw.text((x + mark_w + gap - box[0], (h - (box[3] - box[1])) / 2 - box[1]),
              WORDMARK, font=font, fill=(255, 255, 255))
    return banner


def main() -> int:
    if not SOURCE.exists():
        sys.exit(f"no icon at {SOURCE}")
    src = Image.open(SOURCE)
    colour = brand_colour(src)
    OUT.mkdir(parents=True, exist_ok=True)

    icon_path = OUT / "icon-512.png"
    make_icon(src, colour).save(icon_path, "PNG")
    feature_path = OUT / "feature-1024x500.png"
    make_feature(src, colour).save(feature_path, "PNG")

    for p in (icon_path, feature_path):
        im = Image.open(p)
        print(f"{p.relative_to(ROOT)}  {im.size[0]}×{im.size[1]}  {im.mode}  "
              f"{p.stat().st_size / 1024:.0f} KB")
    print(f"brand colour: #{colour[0]:02X}{colour[1]:02X}{colour[2]:02X}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
