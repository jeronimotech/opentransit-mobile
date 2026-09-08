#!/usr/bin/env python3
"""Fit store screenshots onto an exact canvas, as 24-bit PNG with no alpha.

Google Play rejects a screenshot whose long side is more than twice its short
side, which every modern phone capture is (a Pixel 9 Pro is 1280x2856 = 2.23,
an iPhone 17 Pro Max 1320x2868 = 2.17). So the device capture is scaled to fit
a 9:16 canvas and the leftover strips are filled with the screenshot's own top
edge colour, which keeps the app's status-bar tone and reads as a frame rather
than as a letterbox.

    tool/store_resize.py <in-dir> <out-dir> 1080x1920

Apple, by contrast, wants the device's native pixel size, so nothing here is
used for the iOS folders.
"""
import sys
from pathlib import Path

from PIL import Image


def edge_colour(im: Image.Image) -> tuple[int, int, int]:
    """Median-ish colour of the top row: the app's own status-bar background."""
    row = im.crop((0, 0, im.width, 1)).resize((1, 1), Image.Resampling.BOX)
    return row.convert("RGB").getpixel((0, 0))


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    src, dst, size = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    tw, th = (int(x) for x in size.lower().split("x"))
    dst.mkdir(parents=True, exist_ok=True)

    files = sorted(p for p in src.iterdir() if p.suffix.lower() == ".png")
    if not files:
        print(f"no PNGs in {src}", file=sys.stderr)
        return 1
    for p in files:
        im = Image.open(p).convert("RGB")
        scale = min(tw / im.width, th / im.height)
        w, h = round(im.width * scale), round(im.height * scale)
        canvas = Image.new("RGB", (tw, th), edge_colour(im))
        canvas.paste(im.resize((w, h), Image.Resampling.LANCZOS),
                     ((tw - w) // 2, (th - h) // 2))
        out = dst / p.name
        canvas.save(out, "PNG", optimize=True)
        print(f"{p.name}: {im.width}x{im.height} -> {tw}x{th}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
