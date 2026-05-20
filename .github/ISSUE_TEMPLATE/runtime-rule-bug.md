---
name: Runtime rule bug (lookahead / backtrack / reachability / locks-and-keys)
about: One of the five runtime rules misfired -- the reader missed a point-of-no-return warning, gave bad backtrack advice, claimed something was reachable when it wasn't, or missed a lock/key notification.
title: "[reader] "
labels: bug, runtime-rules
---

## Which rule misfired?

<!-- Pick one or more: Routing (Rule 1), Lookahead (Rule 2), Backtrack (Rule 3), Reachability (Rule 4), Locks-and-keys (Rule 5). The rule definitions are in principles.md / persona_universal.md. -->

## What happened?

<!-- What the reader said vs. what was actually true in the game. The mismatch is the bug. -->

## What did you expect?

<!-- The runtime behavior the rule promises. Link to the rule if you can find it. -->

## Steps to reproduce

1.
2.
3.

## Your setup

- OS:
- Runtime:
- Guide you were playing (game name + commit if public):
- Player position at the time (zone, last gate, dial settings):

## Was the underlying issue in the corpus or the reader?

<!-- Did the corpus's nav/architecture.md have an incorrect zone graph or lock/key entry, or did the reader misread accurate data? If the corpus is wrong, file at hintforge or the guide's own repo instead. If you're unsure, file here and we'll triage. -->

## Session transcript

<!-- Paste the relevant exchange in a code fence. -->
