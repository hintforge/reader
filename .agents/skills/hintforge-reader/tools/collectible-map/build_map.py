"""Build a guide's live collectible map page from its config -> <guide>/artifacts/full_map.html

    python build_map.py <guide dir>                    # reads <guide>/extract_tools/collectible_map.json
    python build_map.py <guide dir> --out <page.html>  # write somewhere else (the picture path is made relative to it)

The page: the real map picture with pan and zoom, category chips, show all / hide all / hide taken / only taken, codes
on or off, search, and the item list beside the map. Clicking a dot only selects it and shows its entry; marking
happens only in the side panel (the "Mark taken" button and the list tick boxes), so a stray click while panning never
marks anything. The list is never rebuilt on zoom or pan, so it keeps its scroll. Each mark is kept in browser storage
and sent to the artifact launcher's save helper (tools/artifact-launcher/state_bridge.ps1), which writes the guide's
item_status.json; the page re-reads that file every 5 seconds and redraws only the marks, so a mark the reader writes
during play shows up on the second screen without a reload and without moving the map.

Read-only on the catalog and status files. Config reference: catalog_schema.md. Standard library only (Pillow, if
installed, is used only to check the picture size).
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import item_codes as ic  # noqa: E402

TEMPLATE = HERE / "map_page.html"


def landmarks(cfg):
    """Named places drawn as diamonds (fast-travel points, bases, sites). Source: a MapGenie location dump, which is the
    same file the item catalog was built from; each configured MapGenie category id becomes one kind."""
    L = cfg.get("landmarks")
    if not L:
        return [], {}
    kinds = {str(k["id"]): k for k in L["kinds"]}
    det = L.get("detail")
    out = []
    for x in json.load(open(ic.gpath(cfg, L["file"]), encoding="utf-8"))["locations"]:
        k = kinds.get(str(x["category_id"]))
        if not k:
            continue
        lng, lat = float(x["longitude"]), float(x["latitude"])
        desc = re.sub(r"\*\*|\[|\]\([^)]*\)", "", (x.get("description") or "")).strip()
        detail = ""
        if det:
            m = re.search(det["regex"], desc)
            if m and int(m.group(1)):
                w = det.get("word")
                word = (w["then"] if w["contains"] in desc.lower() else w["else"]) if w else ""
                detail = det["template"].format(n=int(m.group(1)), word=word)
        px, py = ic.to_px(cfg, lng, lat)
        row = dict(name=x["title"], kind=k["kind"], x=round(px, 1), y=round(py, 1), detail=detail)
        if cfg.get("grid"):
            row["cell"] = ic.cell(cfg, lng, lat)
        out.append(row)
    lkind = {k["kind"]: dict(label=k["label"], letter=k["letter"], fill=k["fill"], txt=k["txt"], title=k["title"]) for k in L["kinds"]}
    return out, lkind


def grid_lines(cfg):
    g = cfg.get("grid")
    if not g:
        return None
    s = -1 if ic.y_up(cfg) else 1
    P = lambda a, b: list(ic.to_px(cfg, a, b))
    xs = [g["x0"] + k * g["cell"] for k in range(len(g["cols"]) + 1)]
    ys = [g["y0"] + s * k * g["cell"] for k in range(g["rows"] + 1)]
    return dict(
        labels=g["cols"],
        v=[[P(x, ys[0]), P(x, ys[-1])] for x in xs],
        h=[[P(xs[0], y), P(xs[-1], y)] for y in ys],
        cols=[P(xs[k] + g["cell"] / 2, ys[0]) for k in range(len(g["cols"]))],
        rows=[P(xs[0], ys[k] + s * g["cell"] / 2) for k in range(g["rows"])],
    )


def view_box(cfg, spec, grid, data, size):
    if spec == "image":
        return [0, 0, size[0], size[1]]
    if "grid_pad" in spec:
        p = spec["grid_pad"]
        (gx0, gy0), (gx1, gy1) = grid["v"][0][0], grid["v"][-1][1]
        return [gx0 - p, gy0 - p, gx1 - gx0 + 2 * p, gy1 - gy0 + 2 * p]
    if "items_pad" in spec:
        p = spec["items_pad"]
        xs = [d["x"] for d in data if d["x"] is not None]
        ys = [d["y"] for d in data if d["y"] is not None]
        return [min(xs) - p, min(ys) - p, max(xs) - min(xs) + 2 * p, max(ys) - min(ys) + 2 * p]
    x0, y0, x1, y1 = spec["coords"]
    a, b = ic.to_px(cfg, x0, y0)
    c, d = ic.to_px(cfg, x1, y1)
    return [a, b, c - a, d - b]


def build(cfg, out=None):
    items, st = ic.load(cfg)
    guide_text = ic.guide_entries(cfg, {i["code"] for i in items})
    data = []
    for i in items:
        row = {k: v for k, v in i.items() if k != "category"}
        if row["x"] is not None:
            px, py = ic.to_px(cfg, row["x"], row["y"])
            row["x"], row["y"] = round(px, 1), round(py, 1)
        row.update(guide_text.get(i["code"], {}))
        data.append(row)
    cats = ic.chips(cfg, {d["cat"] for d in data})
    land, lkind = landmarks(cfg)
    grid = grid_lines(cfg)
    im = cfg["image"]
    size = im["size"]
    img_path = ic.gpath(cfg, im["file"])
    try:
        from PIL import Image
        if img_path.exists():
            real = list(Image.open(img_path).size)
            if real != list(size):
                print("WARNING: %s is %s, config says %s" % (img_path.name, real, size))
    except ImportError:
        pass
    out = Path(out).resolve() if out else ic.gpath(cfg, cfg.get("out", "artifacts/full_map.html"))
    href = Path(os.path.relpath(img_path, out.parent)).as_posix()
    views = [dict(label=v["label"], box=view_box(cfg, v["box"], grid, data, size)) for v in cfg["views"]]
    start = next(v["box"] for v in views if v["label"] == cfg.get("start_view", views[0]["label"]))
    t = cfg.get("text", {})
    opt = dict(guide=cfg["guide"], artifact=out.name, storageKey=cfg["storage_key"], rowmax=cfg.get("row_text_max", 0),
               detailWhere=cfg.get("detail_shows_where", True),
               whereLabel={c["category"]: c["where_label"] for c in cfg["categories"] if c.get("where_label")},
               noteLabel=cfg.get("guide_entries", {}).get("notes", {}).get("label", "How to find it"),
               sourceLink=t.get("source_link", ""))
    sty = cfg.get("style", {})
    rep = {
        "__TITLE__": t.get("title", "Collectible map"), "__SUBTITLE__": t.get("subtitle", ""), "__CREDIT__": t.get("credit", ""),
        "__SIDEW__": str(sty.get("sidebar_width", 340)), "__MAPBG__": sty.get("map_bg", "#161f2b"), "__CODEW__": str(sty.get("code_min_width", 38)),
        "__CATS__": json.dumps(cats), "__ITEMS__": json.dumps(data, ensure_ascii=False),
        "__LAND__": json.dumps(land, ensure_ascii=False), "__LKIND__": json.dumps(lkind), "__GRID__": json.dumps(grid),
        "__IMG__": href, "__IMGSIZE__": json.dumps(size), "__VIEWS__": json.dumps(views), "__START__": json.dumps(start),
        "__ZOOM__": json.dumps(cfg.get("zoom_limits", [140, 7000])), "__OPT__": json.dumps(opt, ensure_ascii=False),
        "__ASOF__": st.get("as_of", ""), "__NTAKEN__": str(sum(1 for d in data if d["taken"])),
    }
    html = TEMPLATE.read_text(encoding="utf-8")
    html = re.sub("|".join(re.escape(k) for k in rep), lambda m: rep[m.group(0)], html)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print("items:", len(data), "on map:", sum(1 for d in data if d["x"] is not None), "taken:", sum(1 for d in data if d["taken"]), "->", out)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("guide")
    ap.add_argument("--config")
    ap.add_argument("--out")
    a = ap.parse_args()
    build(ic.load_config(a.guide, a.config), a.out)


if __name__ == "__main__":
    main()
