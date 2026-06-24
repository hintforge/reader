# Contributing

This is a stub. A full `CONTRIBUTING.md` lands with the multi-contributor aggregator design (merge model, claim-format conventions, CI checks).

For now, see [`README.md`](README.md) for issue/PR norms.

## Platform-agnostic load-bearing files

Load-bearing content — rules, triggers, version stamps, format contracts — must not live uniquely in a platform-specific file (`CLAUDE.md`, `AGENTS.md`, `.claude/`). Those files are shims that catch one tool's auto-load and redirect to the neutral core; they carry zero unique authority. New behavior lands in a neutral file (`SKILL.md`, a procedure `.md`, `docs/`) that ships on every platform. A shim is at most a pointer to those homes.

The rationale: hintforge advertises bot-portability. A load-bearing file under a Claude-only name quietly breaks that promise — a Codex or OpenClaw user never gets that content auto-loaded. Keeping shims as thin pointers removes the asymmetry and eliminates silent drift between platforms.

## Issue routing

This is the **reader** repo. Open issues here for:

- Dial behavior (graduated spoilers, escalation, persona compliance during hints)
- Runtime rules (lookahead, backtrack queries, reachability checks, locks-and-keys notifications)
- Persona discipline (player-pull rule, honest-ambiguity rule, file-first rule)
- Vector-extension discovery, corpus-core-version warnings
- Reader-side install / discovery problems on a specific runtime

Open issues at [`hintforge/builder`](https://github.com/hintforge/builder) for:

- Setup wizard behavior, research-brief generation, ingestion / stitch / zipper
- Corpus format spec (`docs/corpus-format.md`) ambiguities
- Builder templates, persona scaffolding, universal-core file shapes

**Edge case.** A bug that surfaces in the reader but turns out to be a corpus-format ambiguity should land here as a triage issue, get diagnosed, then move to `hintforge` (where the format spec lives).

Game-specific guide content lives in that guide's own repo, not here.

## License inheritance

Contributions to this repository are licensed under [CC BY-NC-SA 4.0](LICENSE) -- matching the project license -- unless explicitly noted otherwise in the PR.
