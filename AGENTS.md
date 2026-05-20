# Agents

This repository is the **Hintforge reader** skill -- a runtime spoiler-controlled hint companion for video game guides authored in Hintforge format.

## Skill location

The skill lives at [`.agents/skills/hintforge-reader/SKILL.md`](.agents/skills/hintforge-reader/SKILL.md). This path is read identically by Claude Code, Codex CLI (which scans `.agents/skills/` from cwd up), and OpenClaw.

## Companion skill

The corresponding *builder* skill (used to author new guides) is at [`hintforge`](https://github.com/dtiger1889-ops/hintforge). The two skills together replace what was previously a single monolithic framework.
