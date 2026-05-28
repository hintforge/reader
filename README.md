# hintforge-reader

**Spoiler-controlled hint companion for any video game guide you've installed.**

A runtime AI skill that loads a Hintforge-format game guide from your workspace and answers your in-game questions in the guide's persona voice, on graduated spoiler dials you set at the start. Two dials (enemy 0-5, puzzle 0-3) control how much it volunteers. It reads the guide's files before answering -- never from training data.

## Install

Paste this into Claude Code, Codex, or OpenClaw:

> Install the hintforge-reader skill from github.com/dtiger1889-ops/hintforge-reader

Per-runtime details in [`docs/install/`](docs/install/).

## Get started in 3 steps

1. **Install the skill on your AI runtime.** Pick your runtime:
   - [Claude Code](docs/install/claude-code.md)
   - [Codex (CLI + desktop)](docs/install/codex.md)
   - [OpenClaw](docs/install/openclaw.md)
2. **Drop a Hintforge-format guide folder into your workspace.** Each guide is a folder with the universal core (`nav/`, `items/`, `sections/`, `_overflow/`, plus `CHECKPOINT.md`, `persona.md`, etc.).
3. **Open a session in the guide folder and ask for help.** Try "where was I" or "I'm stuck, where do I go?"

**You'll know it's working when** the reader greets you in the guide's persona voice and asks you to confirm your spoiler tiers before answering anything substantive.

> **Model recommendation.** Tested and verified on mid-tier models (Sonnet-class) with extended thinking off. Higher-tier models (Opus-class) work too -- the persona voice tends to sound more distinctive and the answers more nuanced -- but they may be "too helpful," volunteering information that brushes against your spoiler gates, and they cost significantly more per session. Mid-tier is the sweet spot for most players.

## What the reader does

- **Two-dial spoiler control.** Enemy tier 0-5, puzzle tier 0-3. Set at session start, changeable any time. Defaults to tier 0 / tier 0 (most spoiler-free).
- **Persona-flavored delivery.** Each guide casts its own voice (`persona.md` in the guide folder). The reader applies the active voice to user-facing text. Voice flavors *how*, never *what*.
- **Reads guide files before answering.** A hard procedural gate. If the guide has nothing on a topic, the reader says "my guide doesn't cover this -- want me to search online?" instead of guessing.
- **Honest ambiguity.** When sources contradict or evidence is thin, the reader says so. No borrowed confidence.
- **Hint ladder on request.** Lvl 1 nudge -> Lvl 2 more direction -> Lvl 3 step-by-step. Per-puzzle escalation doesn't change your tier.
- **Lookahead warnings.** When you ask where to go or signal you're about to move on, the reader surfaces any point-of-no-return warnings ("this zone closes if you push past the next major story gate -- finish anything missable here first") so you don't silently walk through a one-way door.
- **Where-was-I recaps.** Resumes cleanly from `CHECKPOINT.md` after long breaks.

## Two habits that make sessions faster

The reader is designed for low-friction session entry, but two small habits on your side keep it that way:

- **End your session with "checkpoint" (or "wrap").** This tells the reader to write your latest position to `CHECKPOINT.md` *and* pre-compute the next session's lookahead. Without it, the next session has to re-compute lookahead on your first nav question, which costs a few extra seconds and reads. With it, the next session opens nearly instantly.
- **State your position when it changes.** "Just entered the Theater" or "I'm at the second polymer door" is enough -- the reader updates `player_position` and uses it to ground every later answer. Stale position is the main reason routing answers go sideways.

That's it -- there's nothing else to configure. The skill activates on its own when you open a session in a guide folder and ask a player-style question.

## What the reader does NOT do

- It does not build, scaffold, or modify guides. That's the [`hintforge`](https://github.com/dtiger1889-ops/hintforge) builder skill.
- It does not invent content. If the guide is silent on something, the reader says so.
- It does not push or auto-commit anything. The guide files on your disk are yours to edit or version-control as you like.
- It does not run web research without asking. Token-aware by default: heavy operations require your say-so.

## Architecture

This skill is one half of the Hintforge framework. The other half is the [`hintforge`](https://github.com/dtiger1889-ops/hintforge) builder, which authors guides. The two share a corpus format documented at the builder's [`docs/corpus-format.md`](https://github.com/dtiger1889-ops/hintforge/blob/main/docs/corpus-format.md).

Game-specific persona voices live in each guide's `persona.md`. The voice-agnostic, game-agnostic discipline (player-pull rule, honest-ambiguity rule, file-first rule) lives in this skill's [`persona_universal.md`](.agents/skills/hintforge-reader/persona_universal.md). The reader reads both: discipline from this skill, cast from the guide.

For the full universal rule set, see [`principles.md`](.agents/skills/hintforge-reader/principles.md).

## Maintaining your guide

Your guide corpus was built using the hintforge builder. This section describes how to keep it current as the game patches, DLC ships, or the reader framework updates. Maintenance operations run in the builder, not the reader. See the [hintforge builder repo](https://github.com/dtiger1889-ops/hintforge) for the full builder install.

**Model for all maintenance operations: Sonnet-class, extended thinking off.** Doctor, stitch, zipper, and ingestion are all structural. Confirm your model before starting.

### After a game patch

Patches can change stat values, fix or break mechanics, alter drop rates, or rename items. Claims in the corpus that reference patched content become stale without any visible signal. Doctor's Branch B handles this:

Trigger: `run doctor` in a fresh session inside the game folder, then tell it a patch shipped and give it the patch notes or patch version. Doctor reads `architecture.md` for the current game-version manifest, flags claims that reference content the patch notes touch, and produces a repair plan before changing anything. You confirm the plan before repairs run.

If the patch is large, doctor may invoke the reddit sweep with a scope-query to pull post-patch community findings. That sweep runs in its own subsequent session.

### After a DLC ships

When a DLC ships, run the builder's doctor procedure to scaffold DLC coverage, then resume play in the reader once the corpus is updated.

### Filling coverage gaps

When the reader returns "I don't have reliable data on that" for something that should be in the corpus, it usually means a gap in P2 coverage, a stitch failure that left a claim unresolved, or a P3 dispute that landed as unresolved rather than settled. Doctor's Branch C handles targeted repair:

Trigger: `run doctor`, describe the gap ("the reader can't answer questions about the second boss's loot table"). Doctor reads the relevant corpus files, diagnoses whether the gap is a missing claim, a broken cross-reference, or an unresolved dispute, and either repairs it directly or generates a targeted research brief for a narrow handoff sweep.

Small gaps can often be filled without a full deep-research handoff: tell doctor what you know and it will write the claim directly with appropriate source metadata and confidence flags.

### After a reader (hintforge-reader) update

Reader updates occasionally change how the corpus is interpreted: new dial behavior, new warning tiers, updated persona rules. These changes do not invalidate the corpus unless the `corpus-core-version` increments.

`corpus-core-version` is a single integer in `architecture.md`. The reader declares `MIN_SUPPORTED_CORE` and `MAX_SUPPORTED_CORE`. If your corpus version falls outside the reader's supported range, the reader will warn you at session start and describe what changed. It will not hard-stop; it will proceed and behave as well as it can under the mismatch.

To bring a corpus up to a new version, run `run doctor` and tell it the corpus format migrated to version N. Doctor reads the migration notes for that version bump and applies the required structural changes. Migration notes for each version increment are in `CHANGELOG.md`.

Reader-only updates (persona changes, dial behavior changes, warning-tier changes) that do not bump `corpus-core-version` require no corpus action. Update the reader skill and resume play.

### Periodic check-ins

Even without a patch or DLC, a corpus built from a snapshot of web sources drifts over time as wikis correct errors and community knowledge accumulates. There is no required maintenance cadence; the framework does not nag. When the reader starts returning answers that feel wrong or incomplete, that is the signal to run a targeted doctor pass or a narrow reddit sweep.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for issue-routing guidance (reader-side vs. builder-side bugs).

## License

[CC BY-NC-SA 4.0](LICENSE). Free for personal and creator use; share, remix, adapt with attribution; derivatives must use the same license. Commercial licensing available on request.
