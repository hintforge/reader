# Changelog

All notable, user-visible changes to the hintforge reader land here.

## Unreleased

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
