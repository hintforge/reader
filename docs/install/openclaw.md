# Install on OpenClaw

1. Clone this repo to any local path.
2. Copy `.agents/skills/hintforge-reader/` into your OpenClaw skills directory: `<workspace>/skills/hintforge-reader/` (workspace-local) or `~/.openclaw/skills/hintforge-reader/` (user-wide).
3. Drop a Hintforge-format guide folder into your workspace.
4. Open a session in that workspace.

The skill's description is what ClawHub matches user intent against; trigger it with phrases like "I'm stuck" or "hint for this puzzle".

**Verification.** Ask "where was I" in a session opened inside a guide folder. The reader should greet you in the guide's persona voice and ask which spoiler tier you want.
