"""Draws artifacts.ico for the desktop shortcut.

A dark rounded tile with three amber bars -- a stack of pages, legible at 16px
where a monogram would smear. Re-run only if the mark changes:

    python make_icon.py

Colors match index.template.html (--bg-raised / --accent).
"""

from pathlib import Path

from PIL import Image, ImageDraw

BG = (27, 30, 36, 255)        # --bg-raised
EDGE = (44, 49, 58, 255)      # --line
ACCENT = (224, 164, 88, 255)  # --accent

SIZE = 256
OUT = Path(__file__).with_name("artifacts.ico")


def draw(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = size * 0.04
    radius = size * 0.18
    d.rounded_rectangle(
        [pad, pad, size - pad, size - pad],
        radius=radius, fill=BG, outline=EDGE, width=max(1, int(size * 0.012)),
    )

    # Three left-aligned bars of decreasing width: a stack of pages.
    left = size * 0.24
    bar_h = size * 0.10
    gap = size * 0.09
    top = size * 0.28
    for i, frac in enumerate((0.52, 0.40, 0.28)):
        y = top + i * (bar_h + gap)
        d.rounded_rectangle(
            [left, y, left + size * frac, y + bar_h],
            radius=bar_h / 2, fill=ACCENT,
        )
    return img


def main() -> None:
    master = draw(SIZE)
    sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    master.save(OUT, format="ICO", sizes=sizes)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
