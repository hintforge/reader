# Changelog

All notable, user-visible changes to the hintforge reader land here.

## Unreleased

### `MAX_SUPPORTED_CORE: 3 → 4` -- handle v4 corpora; route achievement-class queries through `achievements.md`; extend Rule 2 lookahead for achievement PoNRs

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- `MAX_SUPPORTED_CORE` bumped from `3` to `4`. `MIN_SUPPORTED_CORE` remains `1`; this reader handles v1, v2, v3, and v4 corpora without warning. v4-specific guidance added: treat `achievements.md` as the first stop for any achievement-class query (player names a specific achievement, asks "what am I about to miss," asks "did I get the X achievement"); follow each matching entry's `vector-binding` to the canonical claim home for full trigger detail. Hidden achievements (`achievement-hidden: yes`) keep their entire heading gated below `progression`-tier (enemy-tier 1); explicit opt-in ("show me the hidden achievements") unlocks them for the session. Session-start corpus discovery note updated: at v4+ the universal core also includes `achievements.md` at corpus root; absence on older corpora is treated as "no achievement tracking in this corpus" rather than as an error.
- `.agents/skills/hintforge-reader/persona_universal.md` -- Rule 1 (Routing) extended with the achievement-class routing rule (achievements.md first, then `vector-binding`). Rule 2 (Lookahead warnings) extended with achievement-PoNR as a fireable condition: when `last_known_gate` is within N gates of a `ponr-window` for an unresolved achievement (read save-watcher state if present, otherwise CHECKPOINT open threads), fire a tier-appropriate warning on the same discipline as zone-graph PoNRs. Hidden-achievement spoiler-safe phrasing: describe the missability without naming the achievement when `achievement-hidden: yes` and the player's tier is below `progression`.

**Compatibility matrix.**

| Corpus version | Reader behavior |
|---|---|
| v1 (`corpus-core-version: 1`) | Read normally; skip `capture-method` lookups; skip game-version session-start surface; no achievement routing. No warning. |
| v2 (`corpus-core-version: 2`) | Read normally; parse `capture-method` silently; skip game-version session-start surface; no achievement routing. No warning. |
| v3 (`corpus-core-version: 3`) | Read normally; parse `capture-method` silently; surface game-version manifest fields; no achievement routing. No warning. |
| v4 (`corpus-core-version: 4`) | Read normally; full v4 behavior (achievement-class routing through `achievements.md`, Rule 2 lookahead extension for unresolved-achievement PoNRs, hidden-flag heading gating). No warning. |
| v5+ (any future bump) | Read with the "newer Hintforge format than I fully understand" warning at session start. |
| Pre-manifest corpus (no `## Hintforge manifest` section in `nav/architecture.md`) | Fall back to filesystem listing for vector extensions per SKILL.md "Session-start behavior" step 3. |

### `MAX_SUPPORTED_CORE: 2 → 3` -- surface game-version manifest fields at session start; never update the manifest

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- `MAX_SUPPORTED_CORE` bumped from `2` to `3`. `MIN_SUPPORTED_CORE` remains `1`; this reader handles v1, v2, and v3 corpora without warning. v3-specific guidance added: read three new required manifest fields from `nav/architecture.md` (`game-version`, `game-version-platform`, `game-version-as-of`) and surface them in the session-start opening preamble as a passive drift-detection prompt. If the player declares drift during the session, cache it in session memory and prepend a one-line drift warning to subsequent version-sensitive answers. The reader **never updates the manifest**: it is a build-time snapshot, and corpus rev-bumps remain a builder-side action (re-running setup, or maintainer hand-edit). Reader may volunteer one reconfirmation prompt per session on version-sensitive questions when the player has not yet declared drift; do not nag. v1/v2 corpora lacking the game-version-* fields read silently -- skip the session-start surface line; the corpus is honestly inside the supported range.

**Compatibility matrix.**

| Corpus version | Reader behavior |
|---|---|
| v1 (`corpus-core-version: 1`) | Read normally; skip `capture-method` lookups; skip game-version session-start surface. No warning. |
| v2 (`corpus-core-version: 2`) | Read normally; parse `capture-method` silently; skip game-version session-start surface. No warning. |
| v3 (`corpus-core-version: 3`) | Read normally; parse `capture-method` silently; surface `game-version` + `game-version-platform` + `game-version-as-of` in session-start preamble; cache player-declared drift; prepend drift warnings to version-sensitive answers when drift declared. No warning. |
| v4+ (any future bump) | Read with the "newer Hintforge format than I fully understand" warning at session start. |
| Pre-manifest corpus (no `## Hintforge manifest` section in `nav/architecture.md`) | Fall back to filesystem listing for vector extensions per SKILL.md "Session-start behavior" step 3. |

### `MAX_SUPPORTED_CORE: 1 → 2` -- accept v2 corpora; parse `capture-method` silently

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- `MAX_SUPPORTED_CORE` bumped from `1` to `2`. `MIN_SUPPORTED_CORE` remains `1`; this reader handles both v1 and v2 corpora without warning. v2-specific guidance added: the new required `capture-method` field on claims (value vocabulary `web_fetch | special_export | breezewiki | archive_ph | manual_paste`) is parsed silently and not surfaced in persona output. The field exists for corpus audit; the persona does not recite it. v1 corpora are read by skipping `capture-method` lookups.

**Compatibility matrix.**

| Corpus version | Reader behavior |
|---|---|
| v1 (`corpus-core-version: 1`) | Read normally; skip `capture-method` lookups. No warning. |
| v2 (`corpus-core-version: 2`) | Read normally; parse `capture-method` silently. No warning. |
| v3+ (any future bump) | Read with the "newer Hintforge format than I fully understand" warning at session start. |
| Pre-manifest corpus (no `## Hintforge manifest` section in `nav/architecture.md`) | Fall back to filesystem listing for vector extensions per SKILL.md "Session-start behavior" step 3. |

### Conventions established by this entry

First real CHANGELOG entry. Format mirrors the builder's matching entry: heading names the version range that moved, Reader section describes the changes, plus a compatibility matrix for the version transitions this reader spans. Persona iteration, prose edits, and other non-format-breaking work continue to NOT require a changelog entry.
