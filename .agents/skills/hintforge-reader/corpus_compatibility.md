# Corpus compatibility -- supported versions 1 through 6

Read the relevant section when routing or parsing a version-specific corpus field. Do not load `nav/architecture.md` merely to check a version at session start: manifest checks and migrations belong to the builder's Doctor procedure. Missing optional fields fall through to the normal routing chain without errors or warnings.

Version map: [Claim capture](#claim-capture-v2) · [Game-version drift](#game-version-drift-v3) · [Achievements](#achievements-v4) · [Entity files](#entity-files-v5) · [Host shims](#host-shims-v6).

## Claim capture (v2)

Parse `capture-method` silently when present. Its values include `web_fetch | special_export | mediawiki_parse | browser_fetch | breezewiki | archive_ph | manual_paste`; it is audit metadata, never persona output. On v1 corpora, skip the absent field. No other reader behavior depends on it.

## Game-version drift (v3)

The manifest carries `game-version` (freeform), `game-version-platform` (required even for single-platform games), and `game-version-as-of` (`YYYY-MM-DD`). Read these lazily only if an in-session query needs them. If the player declares a different patch or platform, cache that in session memory and prepend a one-line drift caveat to subsequent version-sensitive answers.

Never update the manifest: it is a build-time snapshot, and corpus revision bumps belong to the builder. v1/v2 corpora without these fields need no check or warning.

## Achievements (v4)

For an achievement query, start at corpus-root `achievements.md`, then follow each matching entry's `vector-binding` to the canonical claim home for full trigger detail. Examples include a named achievement, a missability question, or checking whether a trigger was completed. Claim overlays are `achievement:`, `achievement-hidden:`, `trigger_type:`, and `genre:`.

Gate the entire heading/name of `achievement-hidden: yes` entries below progression tier (enemy-tier 1). An explicit request to show hidden achievements unlocks them for the session. Missing `achievements.md`, including on v1-v3 corpora, means no achievement tracking; fall through to normal routing without an error. A scaffold with no body content has the same fallback.

See `persona_universal.md` Rule 1 for routing and Rule 2 for achievement point-of-no-return warnings.

## Entity files (v5)

Entity queries start at `<class>/<entity-id>.md`, under `npcs/`, `factions/`, `crew/`, or `reputation/`. Follow its back-pointers to canonical per-axis claim homes. The claim fields are `entity:`, `entity-hidden:`, and `entity-status:`; aggregation and forward cross-references connect these files to the primary-vector content.

For a named hostile NPC whose combat content also lives in `mechanics.md`, read `npcs/<id>.md` first: it holds narrative/tactical synthesis and back-pointers. Follow the pointer to `mechanics.md` for granular combat detail only when the player explicitly asks for it. Generic-mob enemy-vector content still routes to `mechanics.md`.

Gate the heading/name of `entity-hidden: yes` entries below progression tier (enemy-tier 1). An explicit request to show hidden companions or factions unlocks them for the session. `entity-status:` informs the file's current-relationship heading, Combat/Status history sections, and companion-versus-encounter voice where the corpus cast supports that distinction. Keep relationship changes as status history rather than relocating the file.

v5+ corpora use `npcs/` for named hostile NPCs with `entity-status: hostile`. An unmigrated v4 corpus may still use `enemies/`; read those per-zone files normally. Missing entity overlays or class folders on v1-v4 corpora mean no entity aggregation, not an error. If the relevant entity file is missing or an honest empty scaffold, fall through to the question's natural per-axis file.

## Host shims (v6)

On v6 corpora, `CLAUDE.md` and `AGENTS.md` are optional host shims, not corpus data or reader rules. Do not require them for detection or read them as harness content. Use the always-present marker files in `SKILL.md` session-start step 2 to find a guide. Platform comes from the manifest when needed, persona from `persona.md`, and spoiler tiers from `CHECKPOINT.md`.

On v1-v5 corpora, still read a present `CLAUDE.md` for per-game harness rules. All other routing, dials, persona, lookahead, and claim-tag behavior are unchanged between v5 and v6.
