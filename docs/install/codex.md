# Install on Codex (CLI or desktop)

Codex CLI auto-discovers `.agents/skills/` from your working directory up to the repo root, so the easiest install is:

1. Clone this repo to a parent directory of where you keep your guide folders (e.g. clone next to your `Guides/` directory).
2. Inside any guide folder under that parent, run `codex` -- the skill loads automatically.

For Codex desktop, use the Skill Picker to point at `.agents/skills/hintforge-reader/` from the cloned repo; the `agents/openai.yaml` metadata supplies the display name and trigger phrasing.

For a global install, copy `.agents/skills/hintforge-reader/` to `~/.codex/skills/hintforge-reader/`.

**Verification.** Ask "where was I" inside a guide folder. The reader should greet you in the guide's persona voice and ask which spoiler tier you want.
