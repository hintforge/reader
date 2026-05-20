# hintforge-reader

**Spoiler-controlled hint companion for any video game guide you've installed.**

A runtime AI skill that loads a Hintforge-format game guide from your workspace and answers your in-game questions in the guide's persona voice, on graduated spoiler dials you set at the start. Two dials (enemy 0-5, puzzle 0-3) control how much it volunteers. It reads the guide's files before answering -- never from training data.

> Want to **build** a guide from scratch or update one? Go to [`hintforge`](https://github.com/dtiger1889-ops/hintforge) -- the builder skill that walks you through scaffolding a guide for any published video game.
>
> [Pre-built guides coming soon.]

## Get started in 3 steps

1. **Install the skill on your AI runtime.** Pick your runtime:
   - [Claude Code](docs/install/claude-code.md)
   - [Codex (CLI + desktop)](docs/install/codex.md)
   - [OpenClaw](docs/install/openclaw.md)
2. **Drop a Hintforge-format guide folder into your workspace.** Each guide is a folder with the universal core (`nav/`, `items/`, `sections/`, `_overflow/`, plus `CHECKPOINT.md`, `persona.md`, etc.). The reference guide is [Atomic Heart](https://github.com/dtiger1889-ops/hintforge-atomic-heart) (push coming soon -- ask if you want early access).
3. **Open a session in the guide folder and ask for help.** Try "where was I" or "I'm stuck, where do I go?"

**You'll know it's working when** the reader greets you in the guide's persona voice (NORA, Charles, GLaDOS -- whoever the guide casts) and asks you to confirm your spoiler tiers before answering anything substantive.

## What the reader does

- **Two-dial spoiler control.** Enemy tier 0-5, puzzle tier 0-3. Set at session start, changeable any time. Defaults to tier 0 / tier 0 (most spoiler-free).
- **Persona-flavored delivery.** Each guide casts its own voice (`persona.md` in the guide folder). The reader applies the active voice to user-facing text. Voice flavors *how*, never *what*.
- **Reads guide files before answering.** A hard procedural gate. If the guide has nothing on a topic, the reader says "my guide doesn't cover this -- want me to search online?" instead of guessing.
- **Honest ambiguity.** When sources contradict or evidence is thin, the reader says so. No borrowed confidence.
- **Hint ladder on request.** Lvl 1 nudge -> Lvl 2 more direction -> Lvl 3 step-by-step. Per-puzzle escalation doesn't change your tier.
- **Lookahead warnings.** Walks the zone graph forward from your current position; surfaces point-of-no-return warnings before you ask the next question.
- **Where-was-I recaps.** Resumes cleanly from `CHECKPOINT.md` after long breaks.

## What the reader does NOT do

- It does not build, scaffold, or modify guides. That's the [`hintforge`](https://github.com/dtiger1889-ops/hintforge) builder skill.
- It does not invent content. If the guide is silent on something, the reader says so.
- It does not push or auto-commit anything. The guide files on your disk are yours to edit or version-control as you like.
- It does not run web research without asking. Token-aware by default: heavy operations require your say-so.

## Architecture

This skill is one half of the Hintforge framework. The other half is the [`hintforge`](https://github.com/dtiger1889-ops/hintforge) builder, which authors guides. The two share a corpus format documented at the builder's [`docs/corpus-format.md`](https://github.com/dtiger1889-ops/hintforge/blob/split-prep/_builder/docs/corpus-format.md).

Game-specific persona voices live in each guide's `persona.md`. The voice-agnostic, game-agnostic discipline (player-pull rule, honest-ambiguity rule, file-first rule) lives in this skill's [`persona_universal.md`](.agents/skills/hintforge-reader/persona_universal.md). The reader reads both: discipline from this skill, cast from the guide.

For the full universal rule set, see [`principles.md`](.agents/skills/hintforge-reader/principles.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for issue-routing guidance (reader-side vs. builder-side bugs).

## License

[CC BY-NC-SA 4.0](LICENSE). Free for personal and creator use; share, remix, adapt with attribution; derivatives must use the same license. Commercial licensing available on request.
