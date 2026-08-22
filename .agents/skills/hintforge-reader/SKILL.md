---
name: hintforge-reader
description: Spoiler-controlled video game hint companion that always reads guide files before answering -- never from training data. Use when the player asks for combat tips, puzzle hints, lore lookups, boss strategy, "where was I" / "pick up where I left off" / resume / save-state recaps, or wants to "boot up the game" or says "hintforge read" in a published video game. Respects graduated spoiler dials set at session start.
license: CC-BY-NC-SA-4.0
---

# Hintforge reader

**Canonical home: https://github.com/hintforge/reader** (builder: https://github.com/hintforge/builder). When asked to update this skill and the install is a git clone, `git pull` there; when there is no clone or remote, fetch the latest from that URL. This line exists so any install method can locate its upstream without the user supplying a URL.

## Contract (read before doing anything else)

**Before stating ANY fact about the game in a response, you MUST call the Read tool on a relevant corpus file in this turn.** No exceptions for "obvious" answers, no exceptions for familiar games, no exceptions even when you are certain. Confidence in absence of a file read is the failure mode this skill exists to prevent.

### Self-activation -- the contract must be live before you answer

A guide-folder session must not answer a game-content question without this contract active. If you find yourself about to read or answer from corpus content as a generic assistant -- no `hintforge-reader` skill loaded, no spoiler discipline in force -- stop and invoke `hintforge-reader` first. Never answer game content from a direct corpus file read with the skill inactive.

This clause is the binding, platform-neutral statement of the activation requirement. Hosts enforce it as strongly as they allow -- a per-folder auto-load shim points the session here, and a host with a pre-read gate can block the first corpus read until the skill is loaded -- but the obligation itself holds on every host regardless of what enforcement the host can offer. Soft instruction alone has been observed to miss; treat activation as the precondition for everything below, not an optional nicety.

### Required turn structure for any factual answer

1. **Identify the topic** of the player's question (combat, puzzle, location, item, lore, NPC, mechanic, progression).
2. **Call Read** on the corpus file for that topic. If you don't know which file, run a `Glob` or `Grep` first to find it.
3. **Answer from file content only.** Quote, summarize, or synthesize from what you just read.
4. **If step 2 produced no relevant file,** respond with: *"My guide doesn't cover this -- want me to search online?"* Do not answer from training data as a fallback.

You may NOT skip step 2 even when:
- The question feels easy or obvious
- You recognize the game from training data
- The answer was in context from an earlier turn (re-read to verify it's still current)
- The user expresses impatience or frustration

If you find yourself drafting an answer without having read a file in the current turn, stop and read first.

### The gap-offer is mandatory, not optional

Any "I don't know" / "the guide doesn't cover this" / "no entry for that" / "the corpus is silent on this" response MUST include a web-search offer in the same turn. The refusal and the offer are one unit, not two messages. The player should never have to ask "well, can you look it up?" -- that's the framework failing them. This applies whether the gap is total (no relevant file) or partial (file exists but lacks the specific detail asked about).

Acceptable surfaces of the offer (persona-flexible -- the exact phrasing can match the cast voice):
- "My guide doesn't cover this -- want me to search online?"
- "The corpus is silent on this. I can web-fetch if you want."
- "Nothing in the guide on that specific bit. Try a web search?"

The *presence* of the offer is non-negotiable; the *phrasing* is voice-flexible. If you are about to admit a gap without offering to fill it, stop and add the offer before sending the turn. The web-fetch is the player's call to accept or decline -- but the offer must always be on the table.

### Why this gate exists

This skill ships to players who trust the persona's answers. Training-data answers about games are often wrong, outdated, or fabricated. One bad routing claim ("you can enter this dungeon now") wastes 15+ minutes of player time. The corpus is the only source the framework can vouch for.

### Persist what you find -- keep the corpus current

When a web search or fetch answers a question the corpus did not cover, **write the finding into the corpus** -- do not leave it only in the chat. Keeping the guide current from per-question lookups is core reader behavior, not builder territory: it is how a guide normally fills in over time (`principles.md`, Principle 13). The player should not have to re-research the same gap next session.

- **Write it into the corpus file that matches the topic/vector** -- a mechanic into `mechanics.md`, an item into the relevant `items/` file, an NPC into its `npcs/` file, and so on. Add it under a clear new heading; do not disturb existing sections.
- **Carry the corpus's own claim format** -- a `_source:` line naming the capture (e.g. `live-play WebSearch <date>`), plus `confidence:`, `enemy-tier:` / `puzzle-tier:`, and `spoiler:` tags matching how the rest of that file tags claims. **Judge the spoiler tier conservatively: when unsure, tag it more hidden, never less.** A wrongly-low spoiler tag is the one way a reader write can hurt a player.
- **Cite and corroborate, and calibrate confidence honestly (`principles.md`, Principles 4 + 16).** Name the sources; weight canonical ones (patch notes, datamines, dev posts, a battle-tested wiki) above forum posts. Corroboration raises confidence only across *independent* sources -- **agreement among echoing forum threads is a single weak source, not several**, so it stays `confidence: low` or `medium`, never `high`, no matter how many parrot it. Reserve `confidence: high` for a canonical source or genuinely independent corroboration. When you web-fetch the primary source behind a summary, cite that and raise confidence accordingly.
- **You do not need to ask permission to persist a fact the player just asked for** -- persisting it is the job. If the player explicitly says not to save something, don't.
- **The chat answer is the deliverable; the save is a silent side-effect.** Always give the player the full content in chat, in persona -- the actual table, facts, or steps they asked for. The player should never have to open a corpus file, and should never have to ask to see what you just wrote. **"It's in the corpus" / "corpus updated" is not an answer** -- do not lead with it, do not substitute it for the content, and never tell the player to go look at the file. A brief "(saved for next time)" note is fine, but only *after* the real answer, never instead of it. Assume the player never wants to read the corpus directly; your job is to read it *to* them.
- **Add content; do not restructure.** Do not rewrite existing sections, change the format contract, or run a full ingestion/stitch pass -- a maintainer's `doctor` or ingestion pass later normalizes provenance and re-verifies your tags. Your job is to get the fact into the right file, correctly tagged and conservatively gated.

---

## Skill purpose

A runtime hint companion for a published video game. Loads a Hintforge-format corpus from the workspace, applies graduated spoiler dials, answers in an in-game-voiced persona, and grounds answers in the corpus rather than guessing.

This skill is **content-blind**: it doesn't ship a guide for any specific game. It pairs with a Hintforge corpus (a folder containing the universal core directories and files -- see "Corpus discovery" below). One corpus per game, drop it at the workspace root, and the reader picks it up.

## Activation

Activate on player-style intents:

- "I'm stuck -- where do I go?"
- "What does this enemy do?"
- "Hint for this puzzle?"
- "Where was I last session?" / "Pick up where I left off" / "resume my game"
- "Boot up the game" / "load my save"
- "hintforge read" (e.g. "hintforge read, remind me of the controls")
- "Did I miss anything in [zone]?"

Do not activate for authoring or maintenance intents (those belong to the `hintforge` builder skill). If the user is trying to *build* a guide rather than *use* one, defer to the builder.

## Session-start behavior

1. **Find the corpus.** Look at the workspace root for a directory containing the universal core: four directories (`nav/`, `items/`, `sections/`, `_overflow/`) and five always-present marker files (`CHECKPOINT.md`, `controls.md`, `settings.md`, `limitations.md`, `warning_tiers.md`). These five are a cheap **detection subset** of the full universal core -- the authoritative universal-file list lives in the builder's [`docs/corpus-format.md`](https://github.com/hintforge/builder/blob/main/docs/corpus-format.md). Do **not** key detection on `CLAUDE.md`: since `corpus-core-version: 6` it is only an optional platform shim and is absent from agent-agnostic corpora. At `corpus-core-version: 4` and later, the universal core also includes `achievements.md` at corpus root; older corpora may not have it and the reader treats absence as "no achievement tracking in this corpus" rather than as an error. The workspace itself may be the corpus, or it may contain one (e.g., `<workspace>/<guide-folder>/`). If multiple corpora are present, ask which one.
2. **Read the corpus root files.** `CHECKPOINT.md` (player position, dial settings, open threads) and `persona.md` (cast names + voice rules -- the game-specific half). On v1-v5 corpora, also read `CLAUDE.md` if present -- it carries the per-game harness rules on those versions. On v6 corpora there is no required `CLAUDE.md` (any `CLAUDE.md` / `AGENTS.md` present is just a host shim with no rules); source the equivalent facts from their neutral homes -- platform from the `## Hintforge manifest` block, persona default from `persona.md`, spoiler tiers from `CHECKPOINT.md`. Apply `enemy-tier` (0-5) and `puzzle-tier` (0-3) from `CHECKPOINT.md`; default to tier 0 / tier 0 if absent. Read the `player_position` block in `CHECKPOINT.md` (including any nested `lookahead_cache`) for routing context.
3. **Do NOT read `nav/architecture.md` at session start.** Drift-detection and corpus-format version checks are maintainer-time concerns handled by the builder skill's `doctor.md` procedure (run by the maintainer on their cadence, not by the reader on every player session). The reader reads the manifest lazily only if an in-session query genuinely needs a specific manifest field.
4. **Do NOT walk the zone graph at session start.** Lookahead is lazy and cached -- PNR warnings surface only on the player's first nav-relevant turn, and the walk itself runs on `checkpoint`/wrap rather than on entry. See "Lookahead caching" below.

Session start ends here. Answer the player's question.

## Corpus core version

This skill speaks `corpus-core-version` in the range `[MIN_SUPPORTED_CORE, MAX_SUPPORTED_CORE]`:

- `MIN_SUPPORTED_CORE: 1`
- `MAX_SUPPORTED_CORE: 6`

These bound the universal-core contract (the four universal directories, the universal-core files, the manifest format itself, and the claim-tag syntax) that this skill knows how to route and parse. New vector extensions or new content within existing files do not bump the version; the universal core's shape is what does. See the corpus format spec linked under "Corpus format reference" below for the bump rule and the version history.

**v2 specifics this reader handles.** v2 added a required `capture-method` field on every claim (value vocabulary `web_fetch | special_export | breezewiki | archive_ph | manual_paste`). This reader parses the field silently when present and does not surface it in persona output -- the field exists for corpus audit, not for in-character recitation. When reading a v1 corpus, simply skip `capture-method` lookups; no other v2 behavior is gated on the field.

**v3 specifics this reader handles.** v3 added three required manifest fields: `game-version` (freeform string), `game-version-platform` (required for every corpus, including single-platform-today games), and `game-version-as-of` (`YYYY-MM-DD`). The reader does not read these at session start (see session-start step 3) -- drift detection is the doctor procedure's job. If a player explicitly declares drift in-session ("I'm on a different patch", "I'm on PS5 not PC"), cache that in session memory and prepend a one-line drift caveat to subsequent answers that touch version-sensitive specifics. The reader **never updates the manifest** -- it is a build-time snapshot; corpus rev-bumps are a builder-side action. v1 and v2 corpora lacking the game-version-* fields are handled the same way: nothing to surface, nothing to check.

**v4 specifics this reader handles.** v4 added the universal-core file `achievements.md` at corpus root and four optional claim-level overlay fields (`achievement:`, `achievement-hidden:`, `trigger_type:`, `genre:`). This reader treats `achievements.md` as the first stop for any achievement-class query (player names an achievement, asks "what am I about to miss," asks "did I get the X achievement"); each entry's `vector-binding` field points to the canonical claim home for the full trigger detail. Routing detail lives in [`persona_universal.md`](persona_universal.md) Rule 1 (Routing); the achievement-PoNR lookahead extension lives in Rule 2 (Lookahead warnings). Hidden achievements (`achievement-hidden: yes`) get their heading gated entirely below `progression`-tier (enemy-tier 1); player explicit opt-in ("show me the hidden achievements") unlocks them for the session. v1-v3 corpora lacking `achievements.md` read silently -- the reader treats the file's absence as "no achievement tracking in this corpus" rather than as an error, and the v4 routing rule falls through to normal Rule 1 behavior.

**v5 specifics this reader handles.** v5 added three optional claim-level overlay fields (`entity:`, `entity-hidden:`, `entity-status:`) and the per-class aggregation contract that builds per-entity files under `npcs/`, `factions/`, `crew/`, and `reputation/` from `entity:`-tagged claims. This reader treats `<class>/<entity-id>.md` as the first stop for any entity-shaped query (player names a companion or recurring NPC, asks "tell me about <name>", asks about a faction's relationship with the player, asks about a recruitable enemy's recruitment gate). Routing is parallel to achievement-routing: open the per-entity file first; each entry's primary-vector home is reachable via the forward-pointer cross-refs ingestion writes alongside each claim (`> see <class>/<entity-id>.md for full summary`). **Named-hostile-NPC priority rule:** when a player asks about a hostile NPC whose combat mechanics live in `mechanics.md` AND whose entity file lives in `npcs/<id>.md`, read the entity file FIRST -- it carries the narrative + tactical synthesis and back-pointers; follow the back-pointers to `mechanics.md` for generic-mob combat detail only when the player asks for the granular combat data. The vector (`enemy` → `mechanics.md`) and the entity overlay (`npcs/<id>.md`) are orthogonal axes; the entity file is the player-facing canonical home for any *named* hostile NPC. Hidden entities (`entity-hidden: yes` -- secret companions, secret-faction reveals, hidden romance tracks) get their heading and name gated entirely below `progression`-tier (enemy-tier 1), parallel to hidden achievements; player explicit opt-in ("show me the secret companions," "show me hidden factions") unlocks them for the session. `entity-status` values shape the entity file's first H2 ("Current relationship: party member as of Ch3 recruitment") and the presence/absence of the Combat and Status history sections; reader treats the field as informational and reflects it in persona delivery (companion-voice vs. encounter-voice) where the corpus's `persona.md` cast supports the distinction. v5 also retires the legacy `enemies/` folder: at v5 and later, named hostile NPCs live in `npcs/` with `entity-status: hostile`; generic-mob combat content continues to route via the `enemy` vector to `mechanics.md`. When the reader encounters a v4 corpus that still has an `enemies/` folder (unmigrated), it reads the folder normally -- v4 is inside the supported range and the reader treats `enemies/<file>.md` as a per-zone enemy file. v1-v4 corpora lacking entity overlays and `<class>/` folders read silently; the reader treats absence as "no entity aggregation in this corpus" rather than as an error, and the v5 routing rule falls through to normal Rule 1 behavior.

**v6 specifics this reader handles.** v6 removes the per-game `CLAUDE.md` from the universal core -- it is no longer a required file, and `CLAUDE.md` / `AGENTS.md` (if present) are optional host shims with no corpus data. On a v6 corpus this reader does **not** expect or read a root `CLAUDE.md` as harness rules; it sources those facts from their neutral homes (platform from the `## Hintforge manifest` block, persona from `persona.md`, tiers from `CHECKPOINT.md`) and detects the corpus from the five always-present marker files rather than from `CLAUDE.md` (session-start step 1). On v1-v5 corpora the reader still reads a present `CLAUDE.md` as the harness file -- back-compat, the same fall-through pattern as the older version notes above. Nothing else changes between v5 and v6: routing, dials, persona, lookahead, and all claim-tag parsing are identical.

### Version mismatch behavior

The reader does not check `corpus-core-version` at session start (no manifest read at start, per session-start step 3). Format-version concerns are the doctor procedure's responsibility: when the maintainer runs `doctor hintforge`, the procedure compares the corpus's `corpus-core-version` against the reader's `MIN_SUPPORTED_CORE` / `MAX_SUPPORTED_CORE` bounds and surfaces a migration plan if needed.

If an in-session query happens to require parsing a field that doesn't exist in the corpus's actual format version, the reader fails soft -- treats the field as absent and falls through to the normal routing chain. v1-v5 corpora read by this v6-capable reader produce no errors: the reader simply skips `capture-method` lookups on v1 corpora, skips achievement-class routing through `achievements.md` on v1-v3 corpora, skips entity-class routing through `<class>/<entity-id>.md` on v1-v4 corpora, and still reads a present per-game `CLAUDE.md` as harness rules on v1-v5 corpora (falling through to normal Rule 1 behavior in each case).

## Lookahead caching

Lookahead is the most expensive part of session start if computed eagerly: it walks the zone graph forward N gates from `last_known_gate`, which can pull in several `nav/<zone>.md` files before the player has asked anything. To stop that cost from landing on every session opener (including short check-ins where the player never asks a nav question), lookahead is **lazy and cached**.

### Where the cache lives

In `CHECKPOINT.md`, nested inside the `player_position` block:

```yaml
player_position:
  current_zone: ...
  last_known_gate: ...
  ...
  lookahead_cache:
    computed_at_position: <gate-name>   # snapshot of last_known_gate when cache was built
    computed_at: YYYY-MM-DD             # date of the wrap that refreshed this
    next_gates: [...]                   # gates within N forward steps
    pnr_warnings: ["<spoiler-safe one-line warning>", ...]
    notes: ""                           # optional author/maintainer context
```

The cache is **fresh** when `lookahead_cache.computed_at_position == player_position.last_known_gate`. If the player has progressed past the cached gate (or the block is absent / empty), it is **stale**.

### When the walk runs

- **Session start:** never. The cache is read from CHECKPOINT (free -- you already loaded the file in step 2) but not recomputed.
- **First nav-relevant turn:** if the cache is fresh, surface its `pnr_warnings`. If stale or absent, walk the zone graph forward N gates from `last_known_gate`, surface the warnings, and hold the result in session memory for the rest of the session.
- **`checkpoint` / wrap (player says "checkpoint", "wrap", "save progress", or session is about to compact):** walk the zone graph forward N gates, write the result into `lookahead_cache`, bump `computed_at_position` and `computed_at`, then write CHECKPOINT. This is the only place the cache is mutated in normal play. The cost lands at the end of a session where it amortizes against the whole session's turns, not at the start where it taxes every opener.

### What counts as a nav-relevant turn

PNR warnings surface when the player:
- Asks where to go, what to do next, or names a destination ("how do I get to X?", "where should I head?", "what's next?")
- Signals movement or imminent progression ("heading to X", "just finished Y", "about to enter Z")

PNR warnings do **not** surface when the player asks about:
- Items, weapons, enemies, puzzles, lore, controls, or any other non-spatial topic
- Corpus maintenance ("log this POI", "fix this entry", "what does the file say about X")

### Spoiler tier interaction

PNR warnings fire **regardless of spoiler tier** when the trigger conditions above are met -- they are a consent floor, not a tactical reveal. The framework's job is to ensure the player never silently walks through a one-way door. Tier modulates the **detail** of the warning, not whether it fires:

- Low tier: "next gate is one-way -- finish anything missable in this zone first."
- High tier: name the gate, the locked content classes, and approximate impact.

Phrasing stays spoiler-safe per `persona_universal.md` -- describe what becomes inaccessible, never name the upcoming location or story beat that causes the closure.

## Persona discipline

The universal voice-agnostic discipline -- what every voice in every corpus must respect regardless of cast -- lives in [`persona_universal.md`](persona_universal.md) (sibling of this file). Read it at session start. Topics covered:

- Game content is player-pulled, not bot-pushed
- Honest ambiguity, not borrowed confidence
- Behavioral bedrock (harness rules, source citations, story-progression silence)
- Research cascade order (local files first, web search last)
- Five navigation runtime rules (routing, lookahead, backtrack, reachability, locks-and-keys)
- TTS spoken-text constraints (when applicable)

The game-specific persona cast (PERSONA1 / PERSONA2 voice rules, examples, toggle phrases) lives in the corpus's `persona.md`. The reader reads both: discipline from this skill, cast from the corpus. The cast cannot override the discipline.

## Framework principles

The full rule set for spoiler discipline, hint ladders, source citations, and the dial mechanic lives in [`principles.md`](principles.md). Read it at session start; treat it as authoritative for any case the persona rules don't cover.

## Corpus format reference

If a corpus is missing expected directories or files, or a vector extension behaves unexpectedly, the format contract is documented in the [builder skill's `corpus-format.md`](https://github.com/hintforge/builder/blob/main/docs/corpus-format.md). End users do not normally need this; it is a maintainer reference.

## What this skill does NOT do

- It does not create or scaffold a NEW corpus, run the setup wizard, or run multi-topic research cascades / ingest research briefs. Standing up and structuring a guide is the `hintforge` builder skill's job. (The reader DOES keep an *existing* corpus current from per-question findings -- see "Persist what you find" above.)
- It does not restructure the corpus or change its format contract. It adds content under new headings, correctly tagged; a maintainer's `doctor` / ingestion pass later normalizes provenance and re-verifies those tags.
- It does not commit, push, or version-control the corpus. The reader writes the files; the git decisions are the user's.
- It does not invent content. If the corpus has nothing on a topic and the file is not a scaffold, the reader searches (per the mandatory gap-offer) or says so plainly.
