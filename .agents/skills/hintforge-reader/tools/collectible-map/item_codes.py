"""Item codes for a guide's collectible map, read from the guide's own config.

    import item_codes as ic
    cfg = ic.load_config(<guide dir>)            # <guide>/extract_tools/collectible_map.json
    items, status = ic.load(cfg)

A code is a category letter plus a number, and it means one item everywhere in the guide (map, list, chat).
Two numberings, chosen in the config:
  "reading_order"  numbered north to south, then west to east, across the whole map (needs a grid);
  "source"         the source's own number (e.g. Relic #12 -> R12), so a code can be checked against that source.
Taken status lives in the guide's item_status.json ("taken": [ids]); the reader and the save helper edit that file.

Everything game-specific (categories, letters, colours, grid, spoiler rules, list groups, sort order) is config,
documented in catalog_schema.md. Standard library only.
"""
import glob
import json
import math
import re
import string
from pathlib import Path

CONFIG_NAME = "extract_tools/collectible_map.json"


class _Fmt(string.Formatter):
    """str.format with one extra conversion: {field!l} lower-cases the value."""

    def convert_field(self, value, conversion):
        if conversion == "l":
            return str(value).lower()
        return super().convert_field(value, conversion)


FMT = _Fmt()


def load_config(guide_dir, config_path=None):
    guide = Path(guide_dir).resolve()
    p = Path(config_path).resolve() if config_path else guide / CONFIG_NAME
    cfg = json.load(open(p, encoding="utf-8"))
    cfg["_guide"] = guide
    cfg["_config"] = p
    return cfg


def gpath(cfg, rel):
    """A config path is relative to the guide folder."""
    return (cfg["_guide"] / rel).resolve()


# ---- predicates shared by spoiler rules, kinds, groups and position notes -------------------------------------------

def matches(when, e):
    """True when every condition in `when` holds for catalog entry e. No `when` = always."""
    if not when:
        return True
    if "category" in when and e.get("category") not in when["category"]:
        return False
    if "truthy" in when and not e.get(when["truthy"]):
        return False
    if "nonzero" in when and not e.get(when["nonzero"], 0):
        return False
    if "regex" in when:
        hit = bool(re.search(when["regex"], str(e.get(when.get("field", "where")) or "")))
        if hit == bool(when.get("negate")):
            return False
    return True


# ---- coordinates -------------------------------------------------------------------------------------------------------

def mercator_tile(lng, lat, z):
    n = 2 ** z
    return (lng + 180.0) / 360.0 * n, (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n


def to_px(cfg, x, y):
    """Source coordinates -> pixels in the base picture."""
    pr = cfg["coords"].get("projection")
    if pr and pr["name"] == "web_mercator":
        tx, ty = mercator_tile(x, y, pr["z"])
        return (tx - pr["x0"]) * 256.0, (ty - pr["y0"]) * 256.0
    return x, y


def y_up(cfg):
    return cfg["coords"]["kind"] == "lnglat"


def _colrow(cfg, x, y):
    g = cfg["grid"]
    col = int((x - g["x0"]) // g["cell"])
    row = int(((g["y0"] - y) if y_up(cfg) else (y - g["y0"])) // g["cell"]) + 1
    return col, row


def cell(cfg, x, y):
    cols = cfg["grid"]["cols"]
    col, row = _colrow(cfg, x, y)
    return (cols[col] if 0 <= col < len(cols) else "?") + str(row)


def cell_words(cfg, x, y):
    """Cell for prose: outside the grid reads 'west of A3' / 'east of H4' instead of '?3'."""
    cols = cfg["grid"]["cols"]
    col, row = _colrow(cfg, x, y)
    if col < 0:
        return "west of %s%d" % (cols[0], row)
    if col >= len(cols):
        return "east of %s%d" % (cols[-1], row)
    return cols[col] + str(row)


def _xy(cfg, e, pos):
    """(x, y, approx) in source coordinates, or (None, None, False) when the item has no spot on the map."""
    c = cfg["coords"]
    if c["kind"] == "lnglat":
        return e[c.get("x", "lng")], e[c.get("y", "lat")], False
    p = pos.get(e["id"])
    if not p:
        return None, None, False
    return p["x"], p["y"], bool(p.get("approx"))


# ---- spoilers, kinds, groups -------------------------------------------------------------------------------------------

def spoil(cfg, e):
    """(where, tier, why). A 'blank' rule empties the text; a 'fold' rule keeps it but marks it to stay folded until
    clicked (tier 1). First matching rule wins."""
    w = e.get("where") or ""
    for r in cfg.get("spoilers", []):
        if matches(r.get("when"), e):
            if r["action"] == "blank":
                return "", 0, ""
            return w, 1, r.get("why", "")
    return w, 0, ""


def kind_of(cat, e):
    """The chip an item is drawn under when its category splits into kinds; the first kind whose `when` holds wins,
    a kind without `when` is the fallback."""
    for k in cat.get("kinds", []):
        if matches(k.get("when"), e):
            return k
    return None


def _rgb(col):
    return "rgb(%d,%d,%d)" % tuple(col) if isinstance(col, list) else col


def chips(cfg, present):
    """Chip list for the page: one per category (or per kind), in config order, skipping any with no items."""
    out = []
    for c in cfg["categories"]:
        base = _rgb(c["color"])
        if c.get("kinds"):
            for k in c["kinds"]:
                key = k.get("cat", c["category"])
                if key in present:
                    out.append(dict(cat=key, letter=c["letter"], name=k["name"], color=_rgb(k.get("color", base)),
                                    shape=k.get("shape", c.get("shape", "circle"))))
        elif c["category"] in present:
            out.append(dict(cat=c["category"], letter=c["letter"], name=c["name"], color=base, shape=c.get("shape", "circle")))
    return out


def group_of(cfg, e):
    """(shown name, real name, hidden?, sort key) from the config's group rules; no rules = no groups."""
    for r in cfg.get("groups", {}).get("rules", []):
        if not matches(r.get("when"), e):
            continue
        real = FMT.format(r["name"], **e)
        field = r.get("order_field", "location")
        k = 0
        if "order" in r:
            v = e.get(field)
            k = r["order"].index(v) if v in r["order"] else r.get("missing", 99)
        hidden = e.get(field) in r.get("hidden", [])
        shown = FMT.format(r["hidden_name"], n=k + 1, **e) if hidden else real
        return shown, real, hidden, (r.get("rank", 0), k)
    return None


def _sort_key(cfg, e, gk):
    key = []
    for s in cfg.get("sort", []):
        if s == "group":
            key.append(gk)
        elif isinstance(s, str):
            key.append(e.get(s, 0))
        elif "category_first" in s:
            f = s["category_first"]
            key.append(f.index(e["category"]) if e["category"] in f else len(f))
        else:
            key.append(s["order"].index(e.get(s["field"])) if e.get(s["field"]) in s["order"] else 0)
    return tuple(key)


# ---- guide text per code (optional) ------------------------------------------------------------------------------------

def guide_entries(cfg, codes):
    """What the guide itself says per code, read from its own markdown tables (config `guide_entries`): the row's
    name and location text with its spoiler tier, the file it lives in, and an optional approach-note line.
    Only codes in `codes` are taken, so a table row whose first cell merely looks like a code is ignored."""
    ge = cfg.get("guide_entries")
    if not ge:
        return {}
    guide = cfg["_guide"]
    tre = re.compile(ge.get("tier_regex", r"enemy-tier:\s*(\d)"))
    tier = lambda s: int((tre.search(s or "") or [0, 0])[1])
    files = []
    for pat in ge["files"]:
        files += sorted(Path(p) for p in glob.glob(str(guide / pat)))
    out = {}
    for f in files:
        rel = "../" + f.resolve().relative_to(guide).as_posix()
        for line in f.read_text(encoding="utf-8").splitlines():
            hit = False
            for r in ge.get("rows", []):
                m = re.match(r["regex"], line)
                if m and m["code"] not in out:
                    name = m["name"].strip()
                    if r.get("name_strip"):
                        name = re.sub(r["name_strip"], "", name)
                    gwt = r["tier"] if "tier" in r else tier(m["tags"])
                    out[m["code"]] = dict(file=rel, name=name, gw=r.get("gw_prefix", "") + m["gw"].strip(), gwt=gwt,
                                          gwhy=r.get("why", "an enemy"))
                    hit = True
                    break
            if hit or "notes" not in ge:
                continue
            m = re.match(ge["notes"]["regex"], line)
            if m and m["code"] in out and "note" not in out[m["code"]]:
                out[m["code"]].update(note=m["note"], nt=tier(m["tags"] or ""))
    return {k: v for k, v in out.items() if k in codes}


# ---- the item list -----------------------------------------------------------------------------------------------------

def load(cfg):
    """Returns (items, status). Each item: id, code, category, cat (chip key), cat_name, title, x, y (source
    coordinates, or None when the item has no spot on the map), approx, where, wt, why, taken, plus cell, the
    config's copied `fields`, short, group, nopos and orbit fields when the config uses them."""
    cat_by = {c["category"]: c for c in cfg["categories"]}
    d = json.load(open(gpath(cfg, cfg["catalog"]), encoding="utf-8"))
    sp = gpath(cfg, cfg["status"])
    st = json.load(open(sp, encoding="utf-8")) if sp.exists() else {"taken": [], "as_of": ""}
    taken = set(st["taken"])
    pos = {}
    if cfg["coords"].get("positions"):
        pp = gpath(cfg, cfg["coords"]["positions"])
        pos = json.load(open(pp, encoding="utf-8"))["positions"] if pp.exists() else {}
    ents = [e for e in d["entries"] if e["category"] in cat_by]
    num = cfg.get("numbering", {"mode": "source"})
    grid = cfg.get("grid")
    reading = num["mode"] == "reading_order"
    if reading:
        # Rows by grid band, then west to east. Items without a map spot cannot be read in map order.
        ents = [e for e in ents if _xy(cfg, e, pos)[0] is not None]
        ents.sort(key=lambda e: (_colrow(cfg, *_xy(cfg, e, pos)[:2])[1], _xy(cfg, e, pos)[0]))
    count = {}
    items = []
    for e in ents:
        c = cat_by[e["category"]]
        l = c["letter"]
        if reading:
            count[l] = count.get(l, 0) + 1
            code = "%s%d" % (l, count[l])
        else:
            code = FMT.format(c.get("code", "{letter}{number}"), letter=l, **e)
        k = kind_of(c, e)
        key = k.get("cat", c["category"]) if k else c["category"]
        chip_name = k["name"] if k else c["name"]
        where, wt, why = spoil(cfg, e)
        x, y, approx = _xy(cfg, e, pos)
        it = dict(id=e["id"], code=code, category=e["category"], cat=key, cat_name=c["name"],
                  title=FMT.format(c.get("title", "{cat_short}"), cat_short=chip_name.split(" (")[0], letter=l, **e),
                  x=x, y=y, approx=approx, where=where, wt=wt, why=why, taken=e["id"] in taken)
        if grid and x is not None:
            it["cell"] = cell(cfg, x, y)
        for out_name, src in cfg.get("fields", {}).items():
            it[out_name] = e.get(src, "")
        if "short_names" in cfg:
            it["short"] = cfg["short_names"].get(e["id"], "")
        g = group_of(cfg, e)
        gk = (0,)
        if g:
            it["group"], it["group_real"], it["group_hidden"], gk = g
            if it["group_hidden"] and not it["wt"]:
                it["wt"], it["why"] = 1, cfg["groups"].get("hidden_why", "a later story place")
        if x is None:
            for r in cfg.get("no_position", []):
                if matches(r.get("when"), e):
                    it["nopos"] = r["text"]
                    break
        orb = c.get("orbit")
        if orb:
            it["orbit"] = orb["slots"].get(e.get(orb["field"]), 0)
            it["scale"] = orb.get("scale", 1)
        it["_k"] = _sort_key(cfg, e, gk)
        items.append(it)
    if not reading:
        items.sort(key=lambda i: i["_k"])
    for i in items:
        i.pop("_k")
    return items, st
