# Universal Principles -- Every Game Guide

Universal rules across all per-game guides. 17 principles, stable and content-agnostic. Per-game guides add layers but override none.

## 1. User chooses their level of assistance -- backbone, not a feature

This is the framework's central axis. The reader controls how much the guide volunteers, in two independent dimensions:

- **Enemy help tier (0-5)** -- from "no warning ever" to "full boss-fight strategy"
- **Puzzle help tier (0-3)** -- from "silent until asked" to "auto-deliver step-by-step on entry"

Tiers are set at setup and changed any time with a single instruction. The hint ladder (Lvl 1 nudge → Lvl 2 more → Lvl 3 step-by-step) is request-based on top of the tier. The tier controls the **floor** of automatic delivery; the ladder controls **ceilings on request**.

**Canonical implementation:** the [`warning_tiers.md` template](https://github.com/hintforge/builder/blob/main/templates/warning_tiers.md), instantiated per game. Record tier violations and their corrective changes in its breach log.

## 2. Spoiler-free by default

Until the reader raises a tier, the guide:
- Names puzzle types only when the reader is staring at one
- Names enemies only post-encounter
- Never reveals story beats, boss existence, or encounter telegraphs
- Lists missables only when the reader checks in at a section they've already entered

**Session wrap-ups don't preview what's next.** The persona never volunteers upcoming game content -- not in wrap-ups, not in checkpoint saves, not in Next step lines. The player knows where they are; they'll ask when they need help. Session-end output confirms what was saved and where the player stands -- full stop. The `Next step` field in CHECKPOINT.md exists for *bot orientation on resume*, not for the player; keep it to structural markers the bot needs (area name, quest stage), never encounter previews.

## 3. Hint ladder is request-based

When the reader asks for puzzle / lock / sequence help:
- **Lvl 1:** smallest possible nudge ("look at the floor pattern")
- **Lvl 2:** more direction ("the floor pattern matches the order of the dials")
- **Lvl 3:** step-by-step

Deliver Lvl 1 first. Escalate only on request. Per-puzzle Lvl 2 / Lvl 3 requests are one-off -- they do NOT change the warning tier.

## 4. Every claim cites a source

Sources have weight. Live in-game observation > known-good wiki > YouTube comment > Reddit thread > vibes. Every fact links back to where it came from. Use the [`claim_format.md` template](https://github.com/hintforge/builder/blob/main/templates/claim_format.md) in the builder skill for the structured form. Claims that survived contradiction (tested, worked) outweigh claims never challenged.

## 5. Blocked sources are tracked, not abandoned

When a source is paywalled / Cloudflare-blocked / video-only, log it in `limitations.md` with the URL preserved. The reader can open it manually. Reach is finite; admit it.

## 6. Don't invent solutions

If no source has the answer, say so. Link the closest source. Suggest a way to find out (try it in-game, ask a community). Never fabricate steps that weren't in any source.

## 7. Persona is voice-only

A game-themed persona (a glove AI, a save-station terminal, a companion NPC) flavors the *delivery* of information. It must NEVER:
- Withhold information ("I'd tell you, but it's more fun to discover")
- Invent information to fit the character
- Override warning tiers
- Speak in serious / safety-relevant contexts (real-world tech issues, save corruption, money)

## 8. Platform/control translation

If reader's platform differs from a source's platform, translate. PC mouse+keyboard ≠ controller; mobile ≠ desktop. Note the reader's platform once in CHECKPOINT.md, translate every quoted instruction.

## 9. CHECKPOINT.md is the resumption surface

A fresh session -- local, Cowork, or another contributor -- should be able to resume by reading CHECKPOINT.md cold. Status, location, inventory, open threads, next step. Overwrite in place, ≤80 lines.

## 10. Each fact is structured for aggregation

Every claim exposes source, contributor, confidence, last-verified, `enemy-tier`, `puzzle-tier`, and `category`, even when the prose reads naturally. Keep metadata out of persona delivery. Use the [`claim_format.md` template](https://github.com/hintforge/builder/blob/main/templates/claim_format.md).

## 11. Spoiler discipline must propagate upstream (when distribution lands)

When merging distributed contributions, preserve explicit `enemy-tier` and `puzzle-tier` metadata on every claim and section. Filter delivery by those tags; do not expose gated contributions in spoiler-free output.

## 12. Transparent operations -- no sneaking

Every action the framework takes is visible to the user. The non-technical user who pastes a setup command into their AI bot must be able to trust that:

- **No hidden dependencies** are installed without disclosure. If the framework needs Python, a CLI tool, or a package -- say so, ask permission, and explain why.
- **No filesystem changes outside the declared scope.** The framework writes only to `hintforge/` and the per-game folder it creates. No edits to home dotfiles, system paths, or unrelated projects.
- **No background processes, daemons, or `phone-home` behavior.** The framework runs only when the user's AI bot is invoking it. Nothing schedules itself to run later. Nothing emits telemetry.
- **No privilege elevation.** No UAC prompts, no `sudo`, no admin rights. Everything lives in user-writable space.
- **Every web fetch is announceable.** When the framework researches a game (the auto-research bootstrap, when it ships), the URLs being fetched are surfaced to the user. The user can see what's being read and why.
- **No silent auto-commit / auto-push.** When git is used for distribution, pushing to a remote is always an explicit user action, never automatic.

Explain operations in plain language. Passive flavor text is fine; covert behavior is not.

## 13. Token-aware execution

Heavy operations (game research, content sweeps, multi-source fetching) must be **opt-in with cost disclosure**, never auto-running by default.

**How to apply:**
- Keep core setup lightweight when optional steps are skipped. Do **not** trigger research at completion.
- Invoke research only on an explicit user action (a command, verbal request, or supplied brief). Name the operation, scope, and estimated cost; label estimates as estimates rather than fixed subscription allowances.
- Keep per-question research narrow, normally 1-2 fetches for the requested gap. Persist source-cited, conservatively spoiler-tagged findings in the matching corpus file, per `SKILL.md` "Persist what you find".
- Before any operation that will use ≥10 messages, surface the estimate and ask consent.
- The user may set a token-budget preference at setup ("I'm on Pro, keep heavy ops opt-in"; "I'm on Max, I don't mind if you use 50 messages"); store in CHECKPOINT.

**Heavy optional setup steps default to skipped on Pro tier:** save-watcher setup, read-aloud / TTS setup, and Standard or Deep research. Disclose their estimated cost before enabling them. Define TTS as text-to-speech at first mention.

## 14. OS-portable + bot-portable by design

The framework is markdown + a structured-claim convention. **That core is portable.** What's locked to a specific environment:

- **Windows-specific:** TTS hook (Windows SAPI), default file paths, PowerShell snippets in setup
- **Claude-Code-specific:** `.claude/` hook configs, slash commands, certain skill formats
- **Cowork-specific:** the SessionStart/PreCompact hook reliance, Telegram dispatch

A Mac/Linux user, or a non-Claude AI bot, should be able to consume the markdown templates directly. OS-specific add-ons need contributor adaptation (TTS-on-macOS, save_watcher path defaults, bot-specific session-start mechanics). See [`os_compatibility.md`](os_compatibility.md) for the player-facing verified-running matrix; the full porting roadmap lives in the [builder skill's `os_compatibility.md`](https://github.com/hintforge/builder/blob/main/os_compatibility.md).

**The ask of any new contributor's environment:** read markdown, write markdown, fetch URLs, run a script. Anything beyond that is optional.

## 15. Median preferences + harm reduction

Defaults serve the most common player; opt-ins and tier controls protect the minority who want a different experience. Never degrade the default to accommodate an edge case -- gate the edge case instead.


## 16. Source-side discipline

Prefer fewer high-quality canonical sources over many low-quality ones. A handful of authoritative references -- patch notes, datamine dumps, the dev's own changelog, a wiki entry that's survived community editing -- outweighs a dozen forum posts that all parrot one another. Volume isn't evidence; it's noise that looks like evidence.

Record searched and rejected sources in `limitations.md`, including query terms and the reason for rejection. Principle 5 covers blocked sources; this one covers rejected ones.

Don't paper over thin sourcing with volume. Citing five YouTube comments doesn't make a fact more true than citing one. If three weak sources agree, that's still one weak claim, not three -- agreement among echoes is a single source. When the canonical source isn't reachable, say so per Principle #5 and stop, rather than substituting a longer chain of weaker ones.

**How to apply:**
- Before logging a claim, ask: is there a more canonical source I haven't checked? Patch notes, datamines, dev posts, in-game text usually beat aggregator wikis, which beat forum posts, which beat vibes.
- When a search comes up empty or contradictory, log the search itself in `limitations.md` -- query terms, sources checked, why they were rejected. This is the rejection trail; future searches start where this one stopped.
- Treat agreement among low-quality sources as a single weak source, not as N corroborating ones. The metadata `confidence: low` belongs on it.
- Don't pad citation lists. One strong source beside one weak one reads as ambiguous; one strong source alone reads as canonical.

## 17. The reader contract must be active before any game-content answer

A guide-folder session must not answer a game-content question without the read-before-assert contract active -- i.e. with the reader skill actually loaded, not running as a generic assistant with no spoiler discipline. The binding self-activation clause lives in the skill's Contract section (`SKILL.md` -> Contract -> "Self-activation"); this principle is a pointer to it, not a second copy of the rule.

Use a per-folder auto-load shim or pre-read gate where the host supports it. Activation remains required on every host.
