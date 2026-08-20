<p align="center">
  <img src="assets/traktion-icon.svg" alt="TRAKTION logo — an amber badge with a white letter T marked with tire-tread notches" width="128">
</p>

<h1 align="center">TRAKTION</h1>

<p align="center"><strong>Modular I/O prompting for the VIZION enhancement tool — Be Right on TRAK.</strong></p>

<p align="center">
  <a href="https://github.com/vaseydev/traktion/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/vaseydev/traktion/ci.yml?branch=main&label=gate" alt="CI gate status"></a>
  <img src="https://img.shields.io/badge/version-0.2.0-blue" alt="Version 0.2.0">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-crimson" alt="License: PolyForm Noncommercial 1.0.0">
  <img src="https://img.shields.io/badge/status-experimental-orange" alt="Status: experimental">
</p>

## What is TRAKTION?

TRAKTION is an experimental I/O prompting tool built to sit alongside **VIZION**, our enhancement tool. Where VIZION enhances, TRAKTION steers: the goal is a set of **modular inputs** through which an enhancement can be **dynamically influenced** — composed per run instead of locked into one monolithic, up-front prompt.

## Status

**Pre-alpha, concept stage.** This repository currently carries the project's documentation, brand assets, and engineering standard; no application code has landed yet.

| Status flag | Meaning |
| --- | --- |
| `experimental` | Interfaces, naming, and scope can change without notice. |
| `concept` | Docs and standards only — nothing runnable ships from this repo yet. |
| `companion` | Designed to pair with VIZION, not to stand alone. |

## Design goals

These are direction, not shipped features:

- **Modular inputs** — prompting building blocks that combine per run, not one fixed prompt.
- **Dynamic influence** — steer the enhancement mid-run through a live input channel.
- **VIZION-native I/O** — the input/output contract is designed around the VIZION enhancement loop from day one.

## Run flags — draft v0

TRAKTION's modular inputs surface as **run flags**: each flag maps to one input module or channel of the [architecture](docs/architecture.md). This registry is the current design spec — nothing is implemented yet, and the full semantics, precedence rules, and open questions live in [`docs/flags.md`](docs/flags.md).

| Flag | Kind | What it does |
| --- | --- | --- |
| `--trak <name>` | module stack | Loads a named stack of input modules (a *trak*) as the run's baseline intent. |
| `--grip <0–100>` | influence weight | How firmly the composed inputs hold VIZION to that intent (100 = strict adherence). |
| `--drift` | latitude | Loosens the hold — VIZION may explore beyond the composed intent where grip allows. |
| `--steer <input>` | live input | Injects a mid-run adjustment through the dynamic channel. Repeatable. |
| `--lock <aspect>` | constraint | Pins an aspect (subject, palette, composition, …) so neither steer nor drift can alter it. Repeatable. |
| `--tap` | feedback | Streams VIZION's output state back to the composer so later inputs can react to it. |
| `--dry` | safety | Composes and prints the full I/O payload without sending anything to VIZION. |

## Quick start

Nothing to install yet — the fastest way in is the docs:

```bash
git clone https://github.com/vaseydev/traktion.git
cd traktion
bash scripts/gate.sh   # run the repo-standard verification gate
```

## Tech stack & environment

- **Stack:** not selected yet — it will be recorded in [`CLAUDE.md`](CLAUDE.md) Project Notes and here when the first implementation lands.
- **Environment variables:** none yet; a documented `.env.example` lands with the first code that needs one.
- **Architecture:** see [`docs/architecture.md`](docs/architecture.md) for the intended TRAKTION ⇄ VIZION shape.

## Notes & updates

- [`CHANGELOG.md`](CHANGELOG.md) — every meaningful change (Keep a Changelog + SemVer).
- [`docs/notes/`](docs/notes/) — dated working notes (`YYYY-MM-DD-topic.md`).
- [`docs/decisions/`](docs/decisions/) — architecture decision records.

## Contributing

All changes follow the engineering standard in [`CLAUDE.md`](CLAUDE.md). Conduct is governed by the [Code of Conduct](CODE_OF_CONDUCT.md); vulnerabilities go through the [security policy](SECURITY.md), not public issues.

Contributions are accepted on the understanding that the project will relicense to MIT when it goes open source — by contributing you grant the maintainer the right to include your contribution under that future license.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE): read, use, modify, and share it for any noncommercial purpose; commercial use is reserved while the project incubates. The plan of record is to relicense under MIT at public open-sourcing (see [`docs/decisions/0002-license-polyform-pending-mit.md`](docs/decisions/0002-license-polyform-pending-mit.md)).

> Required Notice: Copyright 2026 Sean Vasey

---

<p align="center"><sub><strong>VASEY/AI</strong> · AI tooling by Sean Vasey · a Vasey Studios project</sub></p>
