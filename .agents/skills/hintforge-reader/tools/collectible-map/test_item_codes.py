"""Unit checks for item_codes.py and build_map.py that need no browser. Run after any change to either:

    python test_item_codes.py

Builds a tiny throwaway guide in a temporary folder. Exit 0 = all pass.
"""
import json
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import item_codes as ic  # noqa: E402


def guide(tmp, coords, entries, positions=None):
    g = Path(tmp)
    (g / "extract_tools").mkdir(parents=True, exist_ok=True)
    cfg = {
        "format": "hintforge-collectible-map-1", "guide": "test_guide",
        "catalog": "extract_tools/collectible_catalog.json", "status": "extract_tools/item_status.json",
        "storage_key": "test", "coords": coords, "numbering": {"mode": "source"},
        "categories": [{"category": "Relic", "letter": "R", "name": "Relic", "color": [200, 200, 120]}],
    }
    (g / "extract_tools" / "collectible_map.json").write_text(json.dumps(cfg), encoding="utf-8")
    (g / "extract_tools" / "collectible_catalog.json").write_text(json.dumps({"entries": entries}), encoding="utf-8")
    if positions is not None:
        (g / "extract_tools" / "map_positions.json").write_text(json.dumps({"positions": positions}), encoding="utf-8")
    return ic.load_config(g)


def main():
    ok = True

    def check(name, cond, detail=""):
        nonlocal ok
        ok &= bool(cond)
        print(("PASS " if cond else "FAIL ") + name + ("  " + detail if detail else ""))

    entries = [
        {"id": "src:1", "category": "Relic", "number": 1, "lng": -0.5, "lat": 0.5},
        {"id": "src:2", "category": "Relic", "number": 2},                           # no position at all
        {"id": "src:3", "category": "Relic", "number": 3, "lng": None, "lat": None},  # position fields left empty
    ]
    for label, coords, pos in (
        ("lnglat", {"kind": "lnglat", "x": "lng", "y": "lat"}, None),
        ("pixel", {"kind": "pixel", "positions": "extract_tools/map_positions.json"}, {"src:1": {"x": 10, "y": 20}}),
    ):
        with tempfile.TemporaryDirectory() as d:
            try:
                items, _ = ic.load(guide(d, coords, entries, pos))
            except Exception as e:  # noqa: BLE001 -- a crash is the failure being tested
                check(label + ": items without a position load", False, "%s: %s" % (type(e).__name__, e))
                continue
            by = {i["id"]: i for i in items}
            check(label + ": every item gets a code and a row", sorted(by) == ["src:1", "src:2", "src:3"], str(sorted(by)))
            check(label + ": the positioned item keeps its spot", by.get("src:1", {}).get("x") is not None)
            check(label + ": an item with no position has no map spot",
                  all(by.get(k, {}).get("x", 0) is None and by.get(k, {}).get("y", 0) is None for k in ("src:2", "src:3")))

    # A catalog where no item has a position still builds a page: a view fitted to the items falls back to the picture.
    import build_map  # noqa: E402
    with tempfile.TemporaryDirectory() as d:
        cfg = guide(d, {"kind": "lnglat", "x": "lng", "y": "lat"}, entries[1:])
        cfg.update(image={"file": "artifacts/map.png", "size": [800, 600]},
                   views=[{"label": "All", "box": {"items_pad": 20}}], out="artifacts/full_map.html")
        try:
            page = build_map.build(cfg, Path(d) / "artifacts" / "full_map.html")
            html = Path(page).read_text(encoding="utf-8")
            check("no positioned item: the page builds", True)
            m = re.search(r"\bVIEWS=(\[.*?\]), START=", html)
            check("no positioned item: the items view falls back to the whole picture",
                  m is not None and json.loads(m.group(1))[0]["box"] == [0, 0, 800, 600], m.group(1) if m else "no VIEWS line")
        except Exception as e:  # noqa: BLE001 -- a crash is the failure being tested
            check("no positioned item: the page builds", False, "%s: %s" % (type(e).__name__, e))

    # Runs: a guide with no `run:` line keeps its plain storage key and sends run ""; a guide with one gets a per-run key.
    def opt_of(html):
        m = re.search(r"^const OPT=(.*);$", html, re.M)
        return json.loads(m.group(1)) if m else {}
    with tempfile.TemporaryDirectory() as d:
        cfg = guide(d, {"kind": "lnglat", "x": "lng", "y": "lat"}, entries)
        cfg.update(image={"file": "artifacts/map.png", "size": [800, 600]},
                   views=[{"label": "All", "box": "image"}], out="artifacts/full_map.html")
        out = Path(d) / "artifacts" / "full_map.html"
        (Path(d) / "CHECKPOINT.md").write_text("# t\n\n## Player\n- **Name:** P\n", encoding="utf-8")
        o = opt_of(Path(build_map.build(cfg, out)).read_text(encoding="utf-8"))
        check("no run line: storage key unchanged, run empty", o.get("storageKey") == "test" and o.get("run") == "", str(o.get("storageKey")))
        (Path(d) / "CHECKPOINT.md").write_text("# t\n\n## Player\n- **Name:** P\n\nrun: Rebels\n", encoding="utf-8")
        o = opt_of(Path(build_map.build(cfg, out)).read_text(encoding="utf-8"))
        check("run line: page carries the run and a per-run storage key",
              o.get("run") == "Rebels" and o.get("storageKey") == "test@run:Rebels", "%s / %s" % (o.get("run"), o.get("storageKey")))
        # The save helper is told the page's path under artifacts/, the name its manifest entry declares.
        check("page directly in artifacts/ names itself by file name", o.get("artifact") == "full_map.html", str(o.get("artifact")))
        o = opt_of(Path(build_map.build(cfg, Path(d) / "artifacts" / "maps" / "full_map.html")).read_text(encoding="utf-8"))
        check("page in a subfolder names itself by its path under artifacts/", o.get("artifact") == "maps/full_map.html", str(o.get("artifact")))
        # Each run reads its own marks file; a guide without runs reads the configured file.
        st_path = "extract_tools/item_status.json"
        check("run status file is runs/<run>/<status>", build_map.run_status(cfg, "Rebels") == "runs/Rebels/" + st_path)
        check("no run: the configured status file", build_map.run_status(cfg, "") == st_path)
        (Path(d) / "runs" / "Rebels" / "extract_tools").mkdir(parents=True)
        (Path(d) / "runs" / "Rebels" / st_path).write_text('{"as_of": "", "taken": ["src:1"]}', encoding="utf-8")
        (Path(d) / st_path).write_text('{"as_of": "", "taken": ["src:2"]}', encoding="utf-8")
        o = opt_of(Path(build_map.build(cfg, out)).read_text(encoding="utf-8"))
        html = out.read_text(encoding="utf-8")
        baked = {i["id"] for i in json.loads(re.search(r"^const ITEMS=(.*);$", html, re.M).group(1)) if i.get("taken")}
        check("page built for a run shows that run's marks only", baked == {"src:1"}, str(baked))
        for bad in ("CON", "com1", "Lpt9.txt", "(switching 1 -> 2)"):
            try:
                build_map.run_status(cfg, bad)
                check("unusable run name %r refused" % bad, False)
            except SystemExit:
                check("unusable run name %r refused" % bad, True)
    print("ALL PASS" if ok else "SOME FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
