# Collectible map: files and config

A guide opts into the live collectible map with four files. The tool reads them; it never edits the catalog.

| File (guide-relative) | Written by | Holds |
|---|---|---|
| `extract_tools/collectible_catalog.json` | the builder, from a per-item location source | one entry per item |
| `extract_tools/item_status.json` | the reader (pickup reports) and the save helper (page marks) | `as_of`, `note`, `taken: [ids]` |
| `extract_tools/collectible_map.json` | the builder, once | how this game's items become codes, dots and list rows |
| `artifacts/artifacts.json` entry | the builder, once | `"file": "full_map.html", "writes_state": "extract_tools/item_status.json"`, which lets the save helper write that one file |

Optional: `extract_tools/map_positions.json` (`{"positions": {id: {"x", "y", "approx"}}}`) when positions are picture pixels registered from screenshots rather than map coordinates in the catalog.

Commands, from the guide folder (`T` = this folder):

```
python T/fetch_tiles.py .     # only when the config has a tiles block; fetches the picture on this machine
python T/build_map.py .       # -> artifacts/full_map.html
python T/test_map.py artifacts/full_map.html --config extract_tools/collectible_map.json
```

## Catalog entry

```json
{"id": "mapgenie:150752", "category": "Power Core", "where": "On the roof of ...", "lng": -0.71, "lat": 0.52,
 "zone": "...", "nearest_anchor": "North Outpost", "number": 12, "location": "Sector 03", "source_url": "https://..."}
```

- `id`: stable and source-prefixed (`mapgenie:<id>`, `100p:relic-12`); never reused. The save helper accepts only `prefix:name` ids.
- `category`: must match a config category, or the item is left out (that is how a spoiler-tier category, such as bosses, is kept off the map).
- `where`: the source's location text. Spoiler rules blank or fold it; source wording is for private use until paraphrased.
- Position: `lng`/`lat` (with a projection in the config) or an entry in `map_positions.json`. An item with neither still gets a code and a list row, and is markable.
- Anything else (`number`, `tier`, `location`, `open_world`, `window`, `source_url`, `enemy_tier`) is used only when the config names it.

## Config (`collectible_map.json`)

| Key | Meaning |
|---|---|
| `guide`, `storage_key` | guide folder name (the save helper's `guide`) and the page's browser-storage key |
| `catalog`, `status`, `out` | guide-relative paths |
| `image` | `{"file", "size": [w, h]}`, the base picture |
| `tiles` | optional: `{"url" with {z}{x}{y}, "headers", "z", "x": [first, last], "y": [first, last]}` for `fetch_tiles.py` |
| `coords` | `{"kind": "lnglat", "projection": {"name": "web_mercator", "z", "x0", "y0"}}` or `{"kind": "pixels", "positions": "<file>"}` |
| `grid` | optional: `{"x0", "y0", "cell", "cols": "ABCDEFGH", "rows"}` in source coordinates; adds grid lines and a `cell` (C3) per item |
| `numbering` | `{"mode": "reading_order"}` (needs `grid`: north to south, then west to east, over the whole map) or `{"mode": "source"}` (the catalog's own `number`) |
| `categories[]` | `category`, `letter`, `name`, `color` (`[r,g,b]` or CSS), `shape` (`circle`/`square`), `code` (format, default `{letter}{number}`), `title` (detail heading, default `{cat_short}`; `{x!l}` lower-cases), `where_label`, `kinds` (split one category into chips: each `{"cat", "name", "color", "shape", "when"}`; first match wins, no `when` = fallback), `orbit` (`{"field", "slots": {value: -1/0/1}, "scale"}`: draws the item on a small arc above its spot, e.g. chests over their arena) |
| `fields` | `{page field: catalog field}` copied onto each item (`zone`, `anchor`, `number`, `window`, `source_url`, ...) |
| `spoilers[]` | `{"when", "action": "blank" or "fold", "why"}`; first match wins. Fold keeps the text behind a click and says why |
| `detail_shows_where`, `row_text_max` | show the catalog text in the detail panel; cut list rows to N characters (0 = no cut) |
| `groups` | `{"rules": [{"when", "name", "rank", "order_field", "order", "missing", "hidden", "hidden_name"}], "hidden_why"}`: list headings; a `hidden` place shows as `hidden_name` until clicked and its items' text is folded |
| `sort` | list order when numbering is `source`: `"group"`, a field name, `{"category_first": [...]}`, `{"field", "order": [...]}` |
| `no_position[]` | `{"when", "text"}`: why an item has no dot, shown in its detail |
| `short_names` | `{id: text}`: a short list label that replaces `where` |
| `guide_entries` | optional: read the guide's own collectible tables (`files` globs, `rows[]` regexes with named groups `code`, `name`, `gw`, `tags`, optional `tier`, `why`, `gw_prefix`, `name_strip`; `notes` regex with `code`, `note`, `tags` and a `label`) so the detail panel shows the guide's words and links its file |
| `landmarks` | optional: named places from a MapGenie location dump: `file`, `kinds[]` (`id` = MapGenie category id, `kind`, `label`, `letter`, `fill`, `txt`, `title`), `detail` (`regex`, `template` with `{n}` and `{word}`) |
| `views[]`, `start_view` | buttons that fit the map to a box: `"image"`, `{"grid_pad": px}`, `{"items_pad": px}`, `{"coords": [x0, y0, x1, y1]}` |
| `zoom_limits`, `style`, `text` | zoom range in picture pixels; `sidebar_width`, `map_bg`, `code_min_width`; `title`, `subtitle`, `credit`, `source_link` |
| `test` | `hidden_words`, `folded_words`, `min_nopos_rows` for `test_map.py` |

`when` conditions (all must hold): `"category": [...]`, `"truthy": field`, `"nonzero": field`, `"regex": pattern` on `"field"` (default `where`; `(?i)` for case-blind), `"negate": true`.

## Codes

A code is letter + number and names one item everywhere: on the map, in the list and in chat. Reading-order numbering makes nearby codes nearby on the map; source numbering lets a player check a code against the source guide. Changing either the catalog or the numbering renumbers codes, so a guide fixes its numbering before the player starts marking.
