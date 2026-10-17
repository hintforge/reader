"""Fetch and stitch a guide's base map picture from an interactive map's public tiles, on the player's own machine.

    python fetch_tiles.py <guide dir>                 # writes the config's image.file (under artifacts/shots/)
    python fetch_tiles.py <guide dir> --out <x.jpg>   # write somewhere else

Reads the `tiles` block of <guide>/extract_tools/collectible_map.json: a URL pattern with {z} {x} {y}, the zoom, the
tile column and row ranges, and optional request headers. Tiles are cached in <guide>/extract_tools/_tilecache (or
$TILECACHE), so a second run needs no network. The picture is someone else's artwork: it is fetched here, at first
run, and a public guide keeps artifacts/shots/ out of git unless its owner has cleared publishing the picture.
Prints the tile origin, which must match the config's coords.projection x0/y0. Needs Pillow.
"""
import argparse
import os
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import item_codes as ic  # noqa: E402


def fetch(t, cache, z, x, y):
    p = cache / str(z) / str(x) / ("%d.jpg" % y)
    if p.exists() and p.stat().st_size > 0:
        return p
    p.parent.mkdir(parents=True, exist_ok=True)
    url = t["url"].format(z=z, x=x, y=y)
    headers = dict({"User-Agent": "Mozilla/5.0"}, **t.get("headers", {}))
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
                p.write_bytes(r.read())
            time.sleep(0.03)
            return p
        except Exception:
            time.sleep(1 + attempt)
    return None


def stitch(cfg, out):
    from PIL import Image
    t = cfg["tiles"]
    z, (xa, xb), (ya, yb) = t["z"], t["x"], t["y"]
    cache = Path(os.environ.get("TILECACHE", str(cfg["_guide"] / "extract_tools" / "_tilecache")))
    jobs = [(x, y) for y in range(ya, yb + 1) for x in range(xa, xb + 1)]
    with ThreadPoolExecutor(max_workers=4) as ex:
        res = list(ex.map(lambda j: (j, fetch(t, cache, z, j[0], j[1])), jobs))
    im = Image.new("RGB", ((xb - xa + 1) * 256, (yb - ya + 1) * 256), (10, 14, 22))
    miss = 0
    for (x, y), p in res:
        try:
            im.paste(Image.open(p).convert("RGB"), ((x - xa) * 256, (y - ya) * 256))
        except Exception:
            miss += 1
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, quality=88)
    print("z%d tiles x %d-%d y %d-%d -> %s (%dx%d), missing %d" % (z, xa, xb, ya, yb, out, im.width, im.height, miss))
    print("ORIGIN z=%d x0=%d y0=%d" % (z, xa, ya))
    pr = cfg["coords"].get("projection") or {}
    if (pr.get("z"), pr.get("x0"), pr.get("y0")) != (z, xa, ya):
        print("WARNING: config coords.projection does not match this origin; item positions would be off")
    if list(cfg["image"]["size"]) != [im.width, im.height]:
        print("WARNING: config image.size says %s" % cfg["image"]["size"])
    return 1 if miss else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("guide")
    ap.add_argument("--config")
    ap.add_argument("--out")
    a = ap.parse_args()
    cfg = ic.load_config(a.guide, a.config)
    if "tiles" not in cfg:
        print("this guide's config has no tiles block (its picture comes from elsewhere)")
        return 2
    return stitch(cfg, Path(a.out).resolve() if a.out else ic.gpath(cfg, cfg["image"]["file"]))


if __name__ == "__main__":
    sys.exit(main())
