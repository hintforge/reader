# OS + Bot Compatibility -- Player-Facing

What you need to run a hintforge guide on your machine, and what to expect across OS / AI-bot combinations. For the full portability matrix + adaptation roadmap aimed at maintainers and porters, see the [builder skill's `os_compatibility.md`](https://github.com/dtiger1889-ops/hintforge/blob/main/os_compatibility.md).

## Verified-running setup

Verified against a real per-game guide running on:

- **OS:** Windows 11 Pro
- **AI bot:** Claude Code (CLI) + Claude Desktop, Pro/Max tier
- **TTS:** Windows SAPI (Microsoft Zira voice) via PowerShell
- **PTT:** Whisper local transcription via AutoHotkey hotkey

Everything else is **untested but designed to be portable** -- markdown core works anywhere, OS-specific add-ons need adaptation.

## Known gaps

- **TTS / read-aloud** is Windows SAPI + edge-tts only today. Mac (`say`) and Linux (`piper` / `espeak`) variants are roadmap.
- **PTT** assumes AutoHotkey, which is Windows-only. Mac/Linux users skip the module.
- **Save-watcher default paths** only enumerated for Windows. Mac (`~/Library/Application Support/...`) and Linux (`~/.local/share/...` or Proton compat-data) need per-game research; setup wizard accepts a custom path.
- **PowerShell snippets** in some scripts (timestamp generation, file sanity checks). Trivial to translate to bash but unwritten.
- **No installer wrapper yet** -- setup runs via the natural-language paste prompt in the README.

## Honest disclosure for shared guides

If you publish a per-game guide built with hintforge to GitHub, include a "Tested on:" line in its README so receivers know what to expect:

```
Tested on: Windows 11 + Claude Code + Cowork
Likely-works on: Mac/Linux + Claude Code, Claude Desktop, Cursor, any markdown-aware AI agent
Known gaps: TTS hook is Windows-only; save_watcher paths assume Windows defaults
```

This sets honest expectations and invites contribution to fill gaps. The full bot-compatibility bar and adaptation roadmap (for porters) lives in the maintainer-facing companion doc.

## Known incompatibilities

- **Cowork** (Anthropic's collaborative workspace) -- session-scoped, files don't persist locally; tends to hallucinate framework rules instead of loading the per-folder `CLAUDE.md`. The wizard detects this and warns before doing any work.
- **claude.ai in a browser** without a filesystem connector -- same persistence problem.
