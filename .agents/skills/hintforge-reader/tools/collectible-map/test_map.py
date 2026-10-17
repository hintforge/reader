"""Interaction test for a page built by build_map.py (headless Edge or Chrome). Run after ANY change to the page:

    python build_map.py <guide> && python test_map.py <guide>/artifacts/full_map.html --config <guide>/extract_tools/collectible_map.json

Checks what a static screenshot cannot show: the side list keeps its scroll position through map zoom, pan redraws,
list-row clicks and chip toggles; the page itself never scrolls; one wheel tick zooms by a small step; clicking a dot
selects it without marking it; a list tick box marks an item; with the config's `test` block, folded spoiler words and
hidden place names stay out of the list. The test runs on a copy of the page whose save-helper address is unreachable,
in a fresh browser profile, so the guide's item_status.json is never touched.

    --bridge-port N --expect-id ID   instead talk to a save helper on port N (a test fixture, never the real guide):
                                     after zooming, mark ID in that helper's file behind the page's back and check
                                     the page shows it after its 5-second re-read while the map's zoom box stays
                                     the same. ID must not be taken in the page or the fixture file at the start.
Exit 0 = all pass.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

BROWSERS = [
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    os.path.expandvars("%LOCALAPPDATA%/Google/Chrome/Application/chrome.exe"),
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
]

JS = r"""
<script>
setTimeout(()=>{try{
const A=document.querySelector('aside'),R={},svg=document.getElementById('svg'),T=__TESTCFG__;
const wait=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{try{
 A.scrollTop=900;await wait(50);const s0=A.scrollTop;R.listScrollable=A.scrollHeight>A.clientHeight+50;R.s0=s0;
 const w0=svg.viewBox.baseVal.width;
 svg.dispatchEvent(new WheelEvent('wheel',{deltaY:-100,clientX:300,clientY:300,bubbles:true,cancelable:true}));
 await wait(120);R.zoomStep=svg.viewBox.baseVal.width/w0;R.afterWheel=A.scrollTop;
 for(let i=0;i<8;i++){svg.dispatchEvent(new WheelEvent('wheel',{deltaY:60,clientX:400,clientY:300,bubbles:true,cancelable:true}));await wait(30)}
 await wait(120);R.afterManyWheels=A.scrollTop;
 if(T.expectId){
  // Stand-in for the reader marking an item during play: the status file changes behind the page's back (through
  // the helper, as a plain request the page knows nothing about), after the zoom box is recorded.
  const vb0=svg.getAttribute('viewBox'),it=ITEMS.find(i=>i.id===T.expectId);R.expectBefore=it.taken;
  await fetch(T.bridge,{method:"POST",body:JSON.stringify({guide:OPT.guide,artifact:OPT.artifact,id:T.expectId,taken:true})});
  await wait(7000);R.expectAfter=it.taken;R.vbSame=svg.getAttribute('viewBox')===vb0;R.sync=document.getElementById('sync').textContent;
  document.body.setAttribute('data-test',JSON.stringify(R));return}
 const rows=document.querySelectorAll('#list .row');rows[Math.min(25,rows.length-1)].click();await wait(120);R.afterRowClick=A.scrollTop;
 const ch=document.querySelectorAll('.chip'),c=ch[Math.min(3,ch.length-1)];c.click();await wait(120);c.click();await wait(120);R.afterChip=A.scrollTop;
 R.pageScroll=document.scrollingElement.scrollTop;R.docH=document.documentElement.scrollHeight;R.winH=innerHeight;
 const dot=[...svg.querySelectorAll('g')].find(g=>g.__item&&!g.__item.taken);const it=dot.__item;
 dot.firstChild.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,clientX:10,clientY:10,pointerId:1}));
 svg.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,clientX:10,clientY:10,pointerId:1}));await wait(80);
 R.dotSelected=document.getElementById('detail').textContent.includes(it.code);R.dotNotMarked=!it.taken;
 const row=[...document.querySelectorAll('#list .row')].find(r=>!r.querySelector('.tk').checked);const code=row.querySelector('.code').textContent;
 row.querySelector('.tk').click();await wait(80);R.tickMarked=ITEMS.find(i=>i.code===code).taken===true;
 const listText=document.getElementById('list').textContent;
 R.hiddenShown=(T.hidden_words||[]).filter(w=>listText.includes(w));
 R.foldedShown=(T.folded_words||[]).filter(w=>listText.includes(w));
 R.noPosRows=document.querySelectorAll('#list .nopos').length;R.dots=[...svg.querySelectorAll('g')].filter(g=>g.__item).length;
 document.body.setAttribute('data-test',JSON.stringify(R));}catch(e2){document.body.setAttribute('data-test',JSON.stringify({error:'async '+String(e2)}))}
})();}catch(e){document.body.setAttribute('data-test',JSON.stringify({error:String(e)}))}},600);
</script></body>"""


def browser():
    for b in BROWSERS:
        if Path(b).exists():
            return b
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("page")
    ap.add_argument("--config")
    ap.add_argument("--bridge-port", type=int)
    ap.add_argument("--expect-id")
    a = ap.parse_args()
    page = Path(a.page).resolve()
    tcfg = json.load(open(a.config, encoding="utf-8")).get("test", {}) if a.config else {}
    if a.expect_id:
        tcfg = dict(tcfg, expectId=a.expect_id, bridge="http://127.0.0.1:%d/taken" % a.bridge_port)
    exe = browser()
    if not exe:
        print("FAIL: no Edge or Chrome found")
        return 2
    src = page.read_text(encoding="utf-8")
    m = re.search(r'IMG="([^"]*)"', src)
    img = (page.parent / m.group(1)).resolve()
    if not img.exists():
        print("FAIL: map picture missing:", img)
        return 1
    src = src.replace(m.group(0), 'IMG="%s"' % img.as_uri(), 1)
    port = a.bridge_port or 9   # port 9 = nothing listens, so the page's marks never leave it
    src = src.replace("http://127.0.0.1:47831/taken", "http://127.0.0.1:%d/taken" % port)
    src = src.replace("LKEY=OPT.storageKey", 'LKEY=OPT.storageKey+"-TEST"')
    src = src.replace("</body>", JS.replace("__TESTCFG__", json.dumps(tcfg)), 1)
    budget = "20000" if a.expect_id else "8000"
    with tempfile.TemporaryDirectory() as d:
        t = Path(d) / "t.html"
        t.write_text(src, encoding="utf-8")
        r = subprocess.run([exe, "--headless=new", "--disable-gpu", "--window-size=1400,900", "--virtual-time-budget=" + budget,
                            "--user-data-dir=" + str(Path(d) / "prof"), "--dump-dom", t.as_uri()],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    m = re.search(r"data-test='([^']*)'|data-test=\"([^\"]*)\"", r.stdout)
    if not m:
        print("FAIL: page produced no test result (browser %s, %d bytes of page out)" % (exe, len(r.stdout)))
        return 1
    R = json.loads((m.group(1) or m.group(2)).replace("&quot;", '"'))
    if "error" in R:
        print("FAIL: script error", R["error"])
        return 1
    ok = True

    def check(name, cond, detail=""):
        nonlocal ok
        ok &= bool(cond)
        print(("PASS " if cond else "FAIL ") + name + "  " + detail)

    check("list is scrollable", R["listScrollable"])
    check("list keeps scroll after one wheel zoom", abs(R["afterWheel"] - R["s0"]) < 2, "%s -> %s" % (R["s0"], R["afterWheel"]))
    check("list keeps scroll after many wheel ticks", abs(R["afterManyWheels"] - R["s0"]) < 2, "-> %s" % R["afterManyWheels"])
    check("one wheel tick zooms by a small step", 0.8 < R["zoomStep"] < 0.95, "factor %.3f" % R["zoomStep"])
    if a.expect_id:
        check("expected id starts unmarked in the page", R["expectBefore"] is False)
        check("a mark written to the status file shows up after the re-read", R["expectAfter"] is True, R.get("sync", ""))
        check("the re-read does not move the map (viewBox unchanged)", R["vbSame"])
    else:
        check("list keeps scroll after clicking a row (detail box may shift it a few px)", abs(R["afterRowClick"] - R["s0"]) < 60, "-> %s" % R["afterRowClick"])
        check("list scroll survives a chip toggle", abs(R["afterChip"] - R["s0"]) < 60, "-> %s" % R["afterChip"])
        check("page itself does not scroll", R["pageScroll"] == 0 and R["docH"] <= R["winH"] + 2, "docH %s winH %s" % (R["docH"], R["winH"]))
        check("clicking a dot selects it", R["dotSelected"])
        check("clicking a dot does not mark it", R["dotNotMarked"])
        check("a list tick box marks the item", R["tickMarked"])
        if tcfg.get("hidden_words"):
            check("hidden place names stay out of the list", not R["hiddenShown"], str(R["hiddenShown"]))
        if tcfg.get("folded_words"):
            check("folded spoiler words stay out of the list", not R["foldedShown"], str(R["foldedShown"]))
        if tcfg.get("min_nopos_rows"):
            check("items without a map spot are listed", R["noPosRows"] >= tcfg["min_nopos_rows"], "%s rows, %s dots" % (R["noPosRows"], R["dots"]))
    print("ALL PASS" if ok else "SOME FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
