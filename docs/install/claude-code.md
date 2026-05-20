# Install on Claude Code

1. Clone this repo to any local path.
2. Run `/plugin add <path-to-clone>/.agents/skills/hintforge-reader/` from inside Claude Code.
3. Drop a Hintforge-format guide folder into your workspace.
4. Start a new session in that workspace.

**Verification.** Ask "where was I" or "hint for this puzzle" in a session opened inside a guide folder. The reader should greet you in the guide's persona voice and ask which spoiler tier you want before answering.

## Runtime caveats

These are Claude-Code-specific or Cowork-specific notes that don't belong in the OS portability matrix (see [`../../.agents/skills/hintforge-reader/os_compatibility.md`](../../.agents/skills/hintforge-reader/os_compatibility.md)) but matter for anyone running the reader on this runtime.

### Cowork

- **Session-scoped, files don't persist locally between sessions.** The reader relies on the guide folder being present at session start; Cowork sessions lose that state between runs.
- **Tends to hallucinate framework rules** instead of loading the per-folder `CLAUDE.md` and the guide's own files. Cowork isn't the right runtime for sustained reading of a guide; use a persistent Claude Code session instead.

### Browser claude.ai

- Same persistence problem as Cowork without a filesystem connector: files don't persist locally between sessions. Not the right runtime for using a guide over multiple play sessions.
