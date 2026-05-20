---
name: Corpus format ambiguity (may move to hintforge)
about: The reader couldn't parse or route something from the corpus. This might be a reader bug or a corpus-format spec ambiguity -- file here and we'll triage.
title: "[reader/format] "
labels: triage, format-ambiguity
---

## What couldn't the reader handle?

<!-- Describe what you asked, what was in the corpus, and how the reader fell short. The interesting case is when the corpus *looks* well-formed but the reader still misroutes or misses content. -->

## Where in the corpus did the relevant content live?

<!-- File path within the corpus (e.g. `puzzles/combination_locks.md` or `nav/architecture.md` line N). -->

## What does `docs/corpus-format.md` say about this case?

<!-- Link to the relevant section of the format spec, or note if the spec doesn't cover this case at all. -->

## Your setup

- OS:
- Runtime:
- Guide you were playing (game name + commit if public):

## Why this template is "may move to hintforge"

<!-- This template explicitly models the edge-case triage pattern in CONTRIBUTING.md. If diagnosis confirms the bug is in the corpus-format spec (not the reader's interpretation), the issue gets retitled and moved to the hintforge repo. If it's a reader misinterpretation of an unambiguous spec, it stays here. You don't need to figure this out before filing -- describe what happened and we'll route it. -->
