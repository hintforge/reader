"""Unit checks for item_codes.py that need no browser. Run after any change to item_codes.py:

    python test_item_codes.py

Builds a tiny throwaway guide in a temporary folder. Exit 0 = all pass.
"""
import json
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
    print("ALL PASS" if ok else "SOME FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
