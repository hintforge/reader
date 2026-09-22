# Changelog

All notable, user-visible changes to the hintforge reader land here.

## Unreleased

### Gated content needs two signals, and the gate covers every surface (framework v97)

**Reader changes.** In `.agents/skills/hintforge-reader/persona_universal.md`, next to the default-deny clause: gated-class content (spoiler-tiered claims, story, late-game, identity reveals) is delivered only when a content match AND a player-originated signal are both present. The signal is a question naming the entity, a stated "I already know", or a spoiler dial set at session start that covers the tier. The gate now names every surface the reader can read (corpus files, raw save data, web results, pasted screenshots); a surface it was never taught counts as a leak path, not a safe path.

**Docs.** `README.md` and `docs/artifact-launcher.md` now tell Linux and macOS users to build the index with `build_index.ps1` under PowerShell 7 and open `index.html` directly; `launch.ps1` (the Chrome/Edge app window) is Windows-only and was previously documented as working on any platform.

**Compatibility.** No corpus-format change; this is a runtime-behaviour rule.

### Initiative on both sides, properties are looked up not guessed, and the reader says which branch it is writing to (framework v96)

**Reader changes.** All in `.agents/skills/hintforge-reader/persona_universal.md`.

- **New "Initiative" section, deliberately two-sided.** Everything else in this file is written for a player *pulling* content, and the one strong initiative rule points at offering (the mandatory gap-offer), which left the dial mis-set in both directions at once. Two rules now sit on it. *Finish the task you were given:* when the player asks for something that takes several steps, do all of them; offering back a step you can obviously do costs the player a turn to say the yes that was already implied. *Anything irreversible or outward-facing needs an explicit go-ahead, every time:* publishing, sharing, sending, deleting, overwriting a file you did not just create -- ask, and wait. **A pattern is not permission.** The dividing line is whether the action sits inside what was asked and is undoable. The section states explicitly what it does not touch: the mandatory gap-offer, player-pull on game content, and the rule against recording a decision on the player's behalf all stand unchanged.
- **New rule: a named thing's properties are a lookup, not an inference.** What something *is* -- its class, tier, role, the stat it scales off, what it does -- may not be derived from its name, from the company it keeps in a list, from the shape of its icon, or from what similar things usually are. Those are resemblances, not readings. Unread means unclassified, said plainly, with the offer to go and find out and a write-back to the corpus afterwards. This is the counterpart of the existing availability rule: that one forbids claiming a fact about the player's screen you cannot see; this one forbids claiming a fact about the game you have not opened.
- **New rule: say where your writes are actually landing.** A guide folder can be open on a side branch or in a secondary checkout, where every write is real, every push succeeds, and nothing reaches the copy the next session and the published guide read. The reader now resolves the branch once at orientation and names a non-default one in its first message, and it may not claim canonical completion ("fixed", "done", "pushed", "it's live") from such a branch -- those claims get scoped, and the merge is named as the outstanding step. The same rule covers a second trap: a relative path that appears to be missing inside a secondary checkout is evidence about the checkout first, never grounds for concluding the file is absent from the machine, and never something to write into the corpus.

**Compatibility.** No corpus-format change; v1-v6 corpora are unaffected. These are runtime-behavior rules.

### Artifact launcher -- every guide's interactive artifacts in one local window

**New tool.** `.agents/skills/hintforge-reader/tools/artifact-launcher/` -- a local page that scans `<guides-root>/<guide>/artifacts/**/*.html` and lists every artifact across every guide you own, grouped by guide with sub-groups per subfolder, searchable, sortable by name / newest / type. Tabs hold one live frame per open artifact, so switching away from a planner you loaded a save into and back does not reload it. Spoiler class and staleness are read from each guide's `artifacts.json`; an artifact missing from the manifest is still listed rather than hidden. The list collapses to an icon rail (`Ctrl+B`) and a focus mode (`F`) gives the artifact the whole window; pins, tabs and layout persist between launches.

Build it with `build_index.ps1` (Windows PowerShell 5.1 or PowerShell 7), open it with `launch.ps1` in a Chromium app window, and optionally install a desktop shortcut on Windows with `install_shortcut.ps1`. It points itself at your guides by looking for the folder whose children contain `artifacts/`, overridable with `-GuidesRoot` or a `guides_root.txt` beside the script. It reads your files and never writes to them; nothing leaves the machine.

Docs: [`docs/artifact-launcher.md`](docs/artifact-launcher.md). `SKILL.md` gains a short section so the reader can point a player at it, with the caveat that it is player-facing and not part of any answer path.

### Reader keeps the corpus current -- it now writes web-found answers back into the guide

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- new "Persist what you find" subsection in the Contract. When a web search or fetch answers a question the corpus did not cover, the reader writes the finding into the matching corpus file (correct vector, the corpus's own `_source:` / `confidence:` / tier / `spoiler:` claim tags, spoiler tier judged conservatively) instead of leaving it only in chat, so the same gap is not re-researched every session. It adds content under new headings; it does not restructure the corpus, change the format contract, or run a full ingestion pass. It does not prompt for permission to save a fact the player just asked for; an explicit "don't save this" is honored.
- `.agents/skills/hintforge-reader/SKILL.md` -- "What this skill does NOT do" reworded: the reader no longer disclaims *modifying* a corpus (the line that made it refuse to persist findings). It still does not create or scaffold a new corpus, run the setup wizard or research cascades, restructure the format, or commit/push.
- `.agents/skills/hintforge-reader/principles.md` -- Principle 13 ("Token-aware execution") now states that per-question findings are persisted back into the corpus, pointing to the Contract rule.

**Compatibility.** No corpus-format change; v1-v6 corpora are unaffected. This is a runtime-behavior change (the reader now writes found facts into the guide). Reader-written claims carry provisional-grade provenance that a later `doctor` / ingestion pass can normalize; nothing a reader adds changes the format contract or rewrites an existing section.

### Self-activation clause + broadened activation triggers -- the reader must be loaded before answering game content

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- new "Self-activation" subsection in the Contract section. A guide-folder session must not answer a game-content question without the reader contract active; if it is about to read or answer from corpus content as a generic assistant with the skill inactive, it stops and invokes `hintforge-reader` first. This is the binding, platform-neutral statement of the activation requirement that per-platform enforcement (per-folder auto-load shims, and on hosts with a pre-read gate, a block on the first corpus read) points back to.
- `.agents/skills/hintforge-reader/SKILL.md` -- `description` and the Activation intent list broadened to cover resume / save-state / "pick up where I left off" / "boot up the game" / "load my save" / "hintforge read" openers. These previously failed to match the description reliably, so a resume-style opener could land in a session where the skill never activated.
- `.agents/skills/hintforge-reader/principles.md` -- new Principle 17, a pointer to the Contract self-activation clause (no unique authority; the binding rule stays single-sourced in `SKILL.md`).

**Compatibility.** No corpus-format change; v1-v6 corpora are unaffected. This tightens *activation* (whether the skill loads at all), not runtime routing, dials, persona, or lookahead.

### `MAX_SUPPORTED_CORE: 5 → 6` -- v6 corpora carry no required `CLAUDE.md`; detect on neutral markers; source harness facts from neutral homes

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- `MAX_SUPPORTED_CORE` bumped 5 → 6. Session-start step 1 (detection) no longer keys on `CLAUDE.md`: it detects on the five always-present marker files (`CHECKPOINT.md`, `controls.md`, `settings.md`, `limitations.md`, `warning_tiers.md`), back-compatible across v1-v6 since those appear in every version. Session-start step 2 reads `CLAUDE.md` only if present (the v1-v5 harness file); on v6 it sources platform from the `## Hintforge manifest` block, persona from `persona.md`, and tiers from `CHECKPOINT.md` instead. New "v6 specifics this reader handles" paragraph; the version-mismatch enumeration is extended through v5.

**Compatibility.** v1-v5 corpora are unaffected -- the reader still reads a present `CLAUDE.md` as the harness file on those versions (`MIN_SUPPORTED_CORE: 1`). v6 corpora (built by builder v70+) carry no required `CLAUDE.md`; any `CLAUDE.md` / `AGENTS.md` present is an optional host shim the reader does not read as corpus data. See the builder CHANGELOG's matching `corpus-core-version: 6` entry for the format change and the doctor migration path.

### Gap-offer is mandatory whenever the reader admits a gap

- `.agents/skills/hintforge-reader/SKILL.md` -- new "The gap-offer is mandatory, not optional" subsection in the Contract section. Refusal and web-search offer ship as one turn, not two. Covers total gaps (no relevant file) and partial gaps (file exists but lacks the specific detail).
- `.agents/skills/hintforge-reader/persona_universal.md` -- Research cascade step 3: "THEN web-search" -> "**offer to web-search**" with pointer to the SKILL.md mandate. New step 5 for partial gaps. New trailing paragraph rules out the inverse failure (admit-gap-without-offer) symmetrically.

### Lookahead lazy + cached -- defer zone-graph walk from session start to nav-relevant turn / wrap (no corpus-version bump)

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- session-start step 5 now also reads the nested `lookahead_cache` block from `CHECKPOINT.md` alongside `player_position` (free; same Read). Step 6 rewritten: **do NOT walk the zone graph at session start.** New "Lookahead caching" section documents the cache shape (`computed_at_position`, `computed_at`, `next_gates`, `pnr_warnings`, `notes`), the freshness rule (fresh when `computed_at_position == last_known_gate`), when the walk runs (session start = never; first nav-relevant turn = use cache if fresh, else compute on demand and hold in session memory; `checkpoint`/wrap = refresh the cache and write back to CHECKPOINT), the definition of nav-relevant (nav-class question, destination naming, or movement signal -- not item / enemy / puzzle / lore / corpus-maintenance turns), and the PNR-fires-regardless-of-spoiler-tier rule as a consent floor (tier modulates the *detail* of the warning, not whether it fires).
- `.agents/skills/hintforge-reader/persona_universal.md` -- Rule 2 (Lookahead warnings) rewritten to match: lazy on nav-relevant turn, cache-aware, walk amortized to `checkpoint`/wrap. The v4 achievement-PoNR extension inherits the same lazy-cached trigger.
- `README.md` -- "Lookahead warnings" capability bullet updated to describe on-demand surfacing rather than session-start volunteering. New "Two habits that make sessions faster" section: end sessions with "checkpoint" so wrap pre-computes the next session's lookahead; state position when it changes so routing stays grounded.

**Reasoning.**

- **Why lazy.** Eager session-start lookahead reads `nav/architecture.md` plus N zone files before the player has asked anything. Observation-log evidence from a real playtest (a 5-minute check-in where the player's first message was *"what the fuck are you reading, let's go"*) shows the orientation cost is highly visible on short sessions even though it amortizes invisibly on long ones. Most sessions open with an item / enemy / puzzle / lookup question; deferring the walk to nav-relevant turns means non-nav sessions never pay the cost.
- **Why cached, not just lazy.** Pure-lazy means the first nav-relevant turn pays the full walk cost. Caching at `checkpoint`/wrap moves that cost to the end of the previous session where it amortizes against the whole session's turns, so the next session's first nav turn is also fast.
- **Why PNR fires regardless of tier.** PNR warnings are a consent floor, not a tactical reveal. Silently letting a tier-0 player walk through a one-way door is the worse failure mode -- the tier dial is about how much *tactical* spoiler the player wants, not whether they want to be told about irrevocable decisions. Tier modulates the *detail* of the warning (low: "next gate is one-way -- finish anything missable here first"; high: "next gate is one-way and locks zone X, side-quest Y, dialogue Z") rather than whether it fires.

**Compatibility.** Works against all supported corpus versions (v1-v4). CHECKPOINTs that lack the `lookahead_cache` block read normally -- the reader treats absence as "stale, recompute on first nav-relevant turn." The optimization is opt-in per corpus: maintainers who want fast session entry on an existing guide add the empty block under `player_position`, then the next `checkpoint`/wrap populates it. New guides scaffolded by a v4-or-later builder carry the block from creation (see the builder CHANGELOG's matching entry). No corpus-core-version bump because the CHECKPOINT shape is not part of the corpus-core contract.

### `MAX_SUPPORTED_CORE: 4 → 5` -- handle v5 corpora; route entity-class queries through `<class>/<entity-id>.md`; named-hostile-NPC priority rule

**Reader changes.**

- `.agents/skills/hintforge-reader/SKILL.md` -- `MAX_SUPPORTED_CORE` bumped from `4` to `5`. `MIN_SUPPORTED_CORE` remains `1`; this reader handles v1, v2, v3, v4, and v5 corpora without warning. New "v5 specifics this reader handles" paragraph added below the v4 specifics block, covering: (a) the three new claim-level overlay fields (`entity:`, `entity-hidden:`, `entity-status:`); (b) the per-class aggregation contract (`<class>/<entity-id>.md` files built under `npcs/`, `factions/`, `crew/`, and `reputation/` from entity-tagged claims); (c) the named-hostile-NPC priority rule (read entity file first, follow back-pointers to `mechanics.md` for combat granularity only on explicit ask); (d) hidden-entity heading gating below `progression`-tier with explicit-opt-in unlock, parallel to hidden achievements; (e) the `enemies/` retirement and how the reader continues to read unmigrated v4 corpora that still have `enemies/` folders normally. Version-mismatch behavior text updated to include v4 in the inside-range list and to note skipping entity-class routing on v1-v4 corpora.
- `.agents/skills/hintforge-reader/persona_universal.md` -- Rule 1 (Routing) extended with the entity-class routing rule, the named-hostile-NPC priority rule, and the hidden-entity tier-gating rule, parallel to the existing achievement-class routing clause. Falls through to normal Rule 1 behavior when the relevant `<class>/<entity-id>.md` is absent or at scaffold with the honest empty-statement.

**Reasoning.**

- **Why entity files take routing priority over per-axis files.** Entity-shaped queries ("tell me about <name>", "how does <faction> feel about me", "what's <NPC>'s phase 2") express an entity-centric mental model the player carries across sessions. Answering by walking five per-axis files (nav, item, mechanic, missable, achievement) and synthesizing produces inconsistent answers, costs context, and pays a query-time synthesis tax every time. The entity file is the synthesized result; routing to it first matches the player's mental model with the corpus's storage shape.
- **Why named-hostile-NPC priority specifically.** Two destinations carry hostile-NPC content at v5: the entity file (`npcs/<id>.md`, with player-facing synthesis) and `mechanics.md` (with generic-mob combat granularity reachable via the `enemy` vector). Without a priority rule, the reader could open either first; the player-facing synthesis is the better answer for nearly all queries. The back-pointer chain from entity file to mechanics handles the rare case where the player wants the granular combat data.
- **Why no warning fires for v1-v4 corpora.** v1 through v4 stay inside the supported range (`MIN=1`). The reader simply skips entity-class routing on those versions and falls through to normal Rule 1 behavior. For unmigrated v4 corpora that still carry an `enemies/` folder, the reader reads the folder as a per-zone enemy file collection -- the v4-to-v5 builder migration handles the rename at next ingestion, not the reader.

**Compatibility matrix.**

| Corpus version | Reader behavior |
|---|---|
| v1 (`corpus-core-version: 1`) | Read normally; skip `capture-method` lookups; skip game-version session-start surface; no achievement routing; no entity routing. No warning. |
| v2 (`corpus-core-version: 2`) | Read normally; parse `capture-method` silently; skip game-version session-start surface; no achievement routing; no entity routing. No warning. |
| v3 (`corpus-core-version: 3`) | Read normally; parse `capture-method` silently; surface game-version manifest fields; no achievement routing; no entity routing. No warning. |
| v4 (`corpus-core-version: 4`) | Read normally; full v4 behavior (achievement-class routing through `achievements.md`, Rule 2 lookahead extension for unresolved-achievement PoNRs); no entity routing. If a legacy `enemies/` folder is present (pre-v5 migration), read its files as per-zone enemy file collection. No warning. |
| v5 (`corpus-core-version: 5`) | Read normally; full v5 behavior (entity-class routing through `<class>/<entity-id>.md`, named-hostile-NPC priority rule, hidden-entity heading gating). Class folders `npcs/`, `factions/`, `crew/`, `reputation/` are recognized; legacy `enemies/` folder is not expected and would indicate an incomplete migration. No warning. |
| v6+ (any future bump) | Read with the "newer Hintforge format than I fully understand" warning at session start. |
| Pre-manifest corpus (no `## Hintforge manifest` section in `nav/architecture.md`) | Fall back to filesystem listing for vector extensions per SKILL.md "Session-start behavior" step 3. |

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
