# Agents

This repository is the **Hintforge reader** skill -- a runtime spoiler-controlled hint companion for video game guides authored in Hintforge format.

## Skill location

The skill lives at [`.agents/skills/hintforge-reader/SKILL.md`](.agents/skills/hintforge-reader/SKILL.md). Codex CLI (which scans `.agents/skills/` from the working directory up to the repo root) and OpenClaw (which scans `<workspace>/.agents/skills/`) can find it there. Claude Code does not read `.agents/skills/`: copy the skill folder into `~/.claude/skills/` as described in [`docs/install/claude-code.md`](docs/install/claude-code.md). Install steps for every runtime: [`docs/install/`](docs/install/).

## Companion skill

The corresponding *builder* skill (used to author new guides) is at [`hintforge/builder`](https://github.com/hintforge/builder). The two skills together replace what was previously a single monolithic framework.
