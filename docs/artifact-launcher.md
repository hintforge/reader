# Artifact launcher

A small local page that puts every interactive artifact from every guide you own in one
window, so you can get to them without hunting through folders or re-opening a chat.

Guides build artifacts as self-contained HTML files under `<guide>/artifacts/` — skill
planners, build planners, map planners, inventory browsers, dossiers. Once you have a few
guides, those files are scattered across folders and the fastest way to open one is usually
the wrong one. The launcher scans them all, lists them by guide, and opens them in place.

It reads your files and never writes to them.

## What it gives you

- **Every artifact, grouped by guide**, with sub-groups for any subfolder (`artifacts/maps/`
  becomes a "Maps" heading), and search across all of them.
- **Tabs that keep their state.** Each open artifact holds its own live frame, so switching
  away from a planner you loaded a save into and coming back finds it exactly as you left
  it. Nothing reloads.
- **Spoiler and staleness labels** read straight from each guide's `artifacts.json`, so an
  artifact that is flagged spoiler-bearing or out of date says so before you open it.
- **A collapsible list** (collapses to an icon rail, `Ctrl+B`) and a focus mode (`F`) that
  hands the whole window to the artifact.
- **Pins and recents**, remembered between launches along with your open tabs.

## Requirements

- **PowerShell** to build the index: Windows PowerShell 5.1 (preinstalled on Windows) or
  PowerShell 7 on any platform.
- **A Chromium browser** (Chrome or Edge) for the app-window launcher. Any browser can open
  the generated `index.html` directly.
- **Python with Pillow** — optional, only to regenerate the shortcut icon.

## Setup

The launcher lives in the reader skill at `tools/artifact-launcher/`.

**1. Point it at your guides.** It looks for the folder that holds your guide folders — the
one whose children contain `artifacts/`. If your layout is unusual, tell it explicitly:

```
pwsh -File build_index.ps1 -GuidesRoot "C:\path\to\your\guides"
```

or write that path into `guides_root.txt` next to the script, one line, and it will be used
on every run.

**2. Build the index.**

```
pwsh -File build_index.ps1
```

This writes `index.html` beside the script. Re-run it any time you add artifacts — or let
`launch.ps1` do it for you, which it does on every launch.

**3. Open it.**

```
pwsh -File launch.ps1
```

This refreshes the index and opens it in a browser window with no tabs or address bar. If
the rescan fails it opens the last good index and tells you, rather than leaving you with
nothing.

**4. Optional — a desktop shortcut (Windows).**

```
powershell -ExecutionPolicy Bypass -File install_shortcut.ps1
```

Puts a "Game Artifacts" shortcut on your desktop that runs the launcher hidden. Remove it
with `-Uninstall`, or just delete the shortcut.

## Keys

| Key | Does |
|---|---|
| `/` | Jump to search |
| `Enter` | Open the top match |
| `Up` / `Down` | Browse the list — reuses one preview tab instead of opening many |
| `Ctrl+B` | Collapse the list to an icon rail, or bring it back |
| `F` | Focus mode: hide everything but the artifact |
| `Esc` | Step back out — focus, then search, then the home grid |
| `Ctrl+Tab` | Next tab (`Ctrl+Shift+Tab` for previous) |
| `Alt+1`..`9` | Jump to that tab |
| `Alt+W` | Close the current tab |
| `F11` | Browser fullscreen |

`Ctrl+W` is deliberately not bound: it belongs to the browser window and cannot be
intercepted by a page.

## How it finds things

- It scans `<guides-root>/<guide>/artifacts/**/*.html`, skipping `*.template.html`.
- A guide's display name comes from the first heading of its `README.md`, falling back to
  the folder name.
- Artifact titles, kinds, spoiler class and staleness come from `<guide>/artifacts/artifacts.json`
  when present. Manifest field names vary between guides, so it reads either common shape,
  and **an artifact missing from the manifest is still listed** (marked "unlisted") — a
  stale manifest never hides a file from you.
- The artifact list is baked into `index.html` at build time rather than fetched at runtime,
  because a page opened from `file://` cannot fetch a sibling file.

## Notes

- Everything is local. No server, no network, no telemetry; the page opens over `file://`.
- Pins, tabs and layout live in your browser's local storage for that page, so they are
  per-browser and per-machine.
- `install_shortcut.ps1` is Windows-only. On macOS and Linux, run `launch.ps1`, or open the
  generated `index.html` yourself.
