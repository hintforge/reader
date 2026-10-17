# Install on Claude Code

1. Clone this repo to any local path.
2. Copy the skill folder `.agents/skills/hintforge-reader/` to `~/.claude/skills/hintforge-reader/` (on Windows, `~` is your user folder, `%USERPROFILE%`). This folder is self-contained. To update later, run `git pull` in the clone and copy the folder again, because the copy does not follow the clone.
3. Drop a Hintforge-format guide folder into your workspace.
4. Start a new session in that workspace.

**Verification.** Ask "where was I" or "hint for this puzzle" in a guide-folder session. The reader must load its rule files and read relevant corpus content before answering in the guide's persona voice. It confirms position and spoiler dials on the first play session; returning sessions use the saved settings. If the skill is inactive, invoke `/hintforge-reader` before asking again. Auto-load in guide folders is not guaranteed; the builder's setup can add a safeguard to a guide folder that makes the AI load the reader first (builder setup Step 6.6).

## Runtime caveats

These are Claude-Code-specific or Cowork-specific notes that don't belong in the OS portability matrix (see [`../../.agents/skills/hintforge-reader/os_compatibility.md`](../../.agents/skills/hintforge-reader/os_compatibility.md)) but matter for anyone running the reader on this runtime.

### Cowork

- **Session-scoped, files don't persist locally between sessions.** The reader relies on the guide folder being present at session start; Cowork sessions lose that state between runs.
- **Tends to hallucinate framework rules** instead of loading the per-folder `CLAUDE.md` and the guide's own files. Cowork isn't the right runtime for sustained reading of a guide; use a persistent Claude Code session instead.
