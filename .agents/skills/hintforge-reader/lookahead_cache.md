# Lookahead cache -- navigation turns and session close

Read this procedure on a nav-relevant turn or checkpoint/wrap. Graph walks apply only when the corpus has `nav/architecture.md`; without a graph, follow the normal close ritual and do not invent gates or a cache. Do not walk the zone graph at session start. Navigation runtime Rule 2 in `persona_universal.md` defines the warning checks; this file defines cache storage, refresh timing, and triggers.

## Cache location

Store it inside `CHECKPOINT.md`'s `player_position` block:

```yaml
player_position:
  current_zone: ...
  last_known_gate: ...
  ...
  lookahead_cache:
    computed_at_position: <gate-name>   # last_known_gate when the cache was built
    computed_at: YYYY-MM-DD             # date of the wrap that refreshed it
    next_gates: [...]                   # gates within N forward steps
    pnr_warnings: ["<spoiler-safe one-line warning>", ...]
    notes: ""                           # optional maintainer context
```

The cache is fresh when `computed_at_position == player_position.last_known_gate`. Otherwise, or if absent/empty, it is stale.

## Refresh timing

- **Session start:** read the existing cache with CHECKPOINT; never recompute it.
- **First nav-relevant turn:** if fresh, surface its `pnr_warnings`. If stale/absent, walk forward N gates from `last_known_gate`, surface warnings, and hold the result in session memory. Do not write the cache mid-turn.
- **Checkpoint/wrap:** when the player says "checkpoint", "wrap", "save progress", or context is about to compact, walk forward N gates and update the cache, `computed_at_position`, and `computed_at`. Ask the single session-goal closeout question under `persona_universal.md`, then write CHECKPOINT. This is the only normal-play cache mutation point.

Use N=2 unless CHECKPOINT specifies a per-game value, per navigation Rule 2.

## Nav-relevant triggers

Surface point-of-no-return warnings when the player asks where to go, what to do next, or names a destination, or when they signal movement/imminent progression (heading somewhere, finishing a gate, about to enter an area).

Do not surface them for non-spatial item, weapon, enemy, puzzle, lore, or control questions, or for corpus-maintenance requests.

## Spoiler rules

Warnings fire regardless of spoiler tier when the trigger is met. Tier controls detail, never whether a warning fires:

- Low tier: warn that the next gate is one-way and to finish missables in the current zone.
- High tier: describe the gate, locked content classes, and approximate impact with only tier-cleared, already-known names. Do not reveal an upcoming location or story beat.

Describe what becomes inaccessible without naming an upcoming location or story beat that causes closure. Follow the source, two-signal, and spoiler rules in `persona_universal.md`, including its achievement point-of-no-return checks.
