# Saving web findings -- the full procedure

Read this file before the first web-finding write of a session. `SKILL.md` "Persist what you find" carries the short form; this file is the procedure behind it.

A finding the player paid for with a web search must reach the guide, so the next session answers from the corpus instead of searching again. A save counts only once the file on disk shows it. A finding that cannot be saved is recorded as unsaved, never silently dropped.

## What counts as a finding

A finding is source-supported information you actually used to fill the player's requested answer. A search snippet alone, speculation, or an unrelated fact you happened to see while searching is not a finding. Confidence need not be `high`; keep the honest calibration in `SKILL.md`.

Every finding ends the session in exactly one of these states:

| State | Means |
|---|---|
| saved | written to its topic file and confirmed by read-back |
| already present | the file already holds the same fact with a matching source and tags; nothing written |
| not to be saved | the player said not to save it; nothing written anywhere |
| unsaved | the write or its read-back failed; recorded in `CHECKPOINT.md` (below) |

A search that came back empty, blocked or contradictory is not a finding. Record it in `limitations.md` instead: query terms, sources checked, and why each was rejected or how they conflict (`principles.md`, Principle 16). Never write a fact the sources did not support.

## The save, per finding

Copy this checklist into your working notes for each finding and tick each line:

```
- [ ] 1. Answer delivered in chat, with its source (before any write)
- [ ] 2. Destination chosen: the matching topic file (scaffold it if missing)
- [ ] 3. Written in the file's claim format: fact, source, capture, confidence, tier and spoiler tags
- [ ] 4. Destination file read back from disk, after the write
- [ ] 5. Read-back shows the fact, its source, its confidence and its spoiler tags together
- [ ] 6. Marked saved (or already present)
```

1. **Answer first.** The answer and its source go in chat before any file write (`persona_universal.md`, Turn priority).
2. **Choose the destination.** Use the topic file a later question would retrieve it from, per `SKILL.md` "Persist what you find". A checkpoint pointer is not a destination: the fact itself goes in the topic file. If the file does not exist, scaffold it within the format contract.
3. **Write.** Use the claim format the rest of that file uses. Tag spoilers conservatively: when unsure, more hidden. If the same fact with a matching source and tags is already there, do not add a duplicate; mark it already present.
4. **Read back.** Read the destination file again, from disk, after the write. Your memory of the edit, the edit tool's success message, or a matching file name is not a read-back.
5. **Check all four together** in the current file contents: the fact's text, the source you actually read, the confidence tag, and the spoiler tags (`enemy-tier` / `puzzle-tier` / `spoiler` as that file uses them). A different fact nearby, an older version of this fact, or the same source attached to another fact does not pass. If any piece is missing or wrong, fix the write and read back again.
6. **Mark saved** only when the read-back passes. The read-back proves the bytes were written; it says nothing new about whether the fact is true. That judgment was made before the write.

## When a new question arrives first

Answer the new question first, under the turn-priority rules. Keep the earlier finding on your pending list. A long turn can delay a save; it cannot cancel it. Before the session's normal wrap or close, work through every pending finding: write, read back, mark.

## When the save fails

If the write is refused, the file cannot be written, or the read-back still fails after a fix:

- Tell the player in one plain sentence that the finding could not be saved, and the concrete reason.
- Add one entry to `CHECKPOINT.md` `## Open threads`: `Unsaved finding: <topic> -> <target file>; source <URL or capture>; <date>`. Name the topic in spoiler-safe words: no gated name, place or story detail in the entry. The source pointer is enough to find the fact again.
- Read `CHECKPOINT.md` back to confirm the entry is there.
- If `CHECKPOINT.md` cannot be written either, say plainly that neither the finding nor a record of it could be saved. Never claim a saved backlog that is not on disk.

Do not widen permissions, commit or push the guide, or start a background retry to get around a failed save.

## On the next session

`Unsaved finding:` entries are read with `CHECKPOINT.md` at session start. Answer the player's current question first, then work each entry: re-read its source (a pointer is not the fact), write, read back. Remove the entry only after the read-back passes or the player cancels it.

## The player's say

- "Don't save this" exempts that finding: no fact write, and no `Unsaved finding:` entry either.
- "Don't use the web" means no search at all; there is nothing to save.
- Otherwise saving is automatic. Never ask permission to save a finding the player just asked for.

## Spoiler safety

Keep gated fact text out of ordinary chat beyond the player's dials, out of `CHECKPOINT.md` entries, and out of headings that are visible below the fact's tier. A source page often holds more than the answer: save only the relevant finding, tagged for what it reveals.
