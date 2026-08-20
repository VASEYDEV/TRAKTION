<p align="center">
  <img src="assets/traktion-icon.svg" alt="TRAKTION logo — an amber badge with a white letter T marked with tire-tread notches" width="128">
</p>

<h1 align="center">TRAKTION</h1>

<p align="center"><strong>Precision reconstruction for content captured in pieces — Be Right on TRAK.</strong></p>

<p align="center">
  <a href="https://github.com/vaseydev/traktion/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/vaseydev/traktion/ci.yml?branch=main&label=gate" alt="CI gate status"></a>
  <img src="https://img.shields.io/badge/version-0.3.0-blue" alt="Version 0.3.0">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-crimson" alt="License: PolyForm Noncommercial 1.0.0">
  <img src="https://img.shields.io/badge/status-experimental-orange" alt="Status: experimental">
</p>

## What is TRAKTION?

TRAKTION is a precision reconstruction utility that turns overlapping screenshots, scroll captures, screen-recording frames, and related visual fragments into **one continuous, editable image** — restoring content captured in pieces back into the continuous form in which it originally existed.

Full-page capture often fails: content scrolls inside nested frames, headers stay fixed, floating controls cover content, or the source app simply has no full-page capture. Manual stitching is slow because every adjacent capture overlaps and must be aligned and trimmed precisely. TRAKTION's deterministic reconstruction engine does that alignment — and reports what it cannot prove instead of inventing it.

## Status

**Foundation stage — no application code yet.** The repository carries the canonical agent contract ([`AGENTS.md`](AGENTS.md)), the full product and architecture spec ([`docs/`](docs/)), phased build prompts ([`prompts/`](prompts/)), and the repo's governance docs. Milestone 1 (a native Swift reconstruction lab, `TraktionLab`) is specified and ready to build — see [`README_FIRST.md`](README_FIRST.md) and [`FOUNDATION_CHECKLIST.md`](FOUNDATION_CHECKLIST.md).

## Design invariants

Contractual, from [`AGENTS.md`](AGENTS.md) — every change is reviewed against them:

- **Deterministic pixels** — deterministic image-processing code owns alignment, seams, rendering, and final pixel selection. An optional semantic reviewer may classify ambiguity; it never authors pixels.
- **No fabrication** — missing coverage is reported, never silently invented or bridged.
- **Non-destructive sources** — original captures are never overwritten; deletion is an explicit user action.
- **Local-first** — core reconstruction, editing, persistence, and export work offline, with no model API.
- **One reviewer provider** — at most one semantic-review provider at runtime, behind an interface.

## Planned modes

Per the [product spec](docs/PRODUCT.md): **Screenshots** (overlapping captures, vertical or horizontal), **Scroll Recording** (frame extraction from screen recordings), and **Web Capture** (native document capture with viewport-reconstruction fallback).

Every joint in a reconstruction carries a confidence state — `exact` · `strong` · `review` · `gap` · `conflict` — and low-confidence states stay visible until resolved, accepted, or exported with an acknowledged warning.

## Quick start

Nothing to build yet — the fastest way in is the spec:

```bash
git clone https://github.com/vaseydev/traktion.git
cd traktion
bash scripts/gate.sh   # run the repo-standard verification gate
```

Read in order: [`AGENTS.md`](AGENTS.md) → [`docs/PRODUCT.md`](docs/PRODUCT.md) → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) → [`docs/RECONSTRUCTION_SPEC.md`](docs/RECONSTRUCTION_SPEC.md). Coding agents start at [`prompts/00_BOOTSTRAP_AGENT.md`](prompts/00_BOOTSTRAP_AGENT.md).

## Tech stack & environment

- **Stack:** native Swift ([ADR-001](docs/adr/ADR-001-native-swift.md)); Milestone 1 targets the `TraktionLab` diagnostic CLI before any polished app.
- **Environment variables:** none yet; a documented `.env.example` lands with the first code that needs one.
- **Architecture:** module boundaries and data flow in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); layout in [`docs/REPO_LAYOUT.md`](docs/REPO_LAYOUT.md).

## Notes & updates

- [`CHANGELOG.md`](CHANGELOG.md) — every meaningful change (Keep a Changelog + SemVer).
- [`docs/notes/`](docs/notes/) — dated working notes (`YYYY-MM-DD-topic.md`).
- [`docs/adr/`](docs/adr/) — product/architecture ADRs · [`docs/decisions/`](docs/decisions/) — repo-governance ADRs.

## Contributing

[`AGENTS.md`](AGENTS.md) is the canonical contract for all contributors and coding agents. Conduct is governed by the [Code of Conduct](CODE_OF_CONDUCT.md); vulnerabilities go through the [security policy](SECURITY.md), not public issues — the app's own security and privacy constraints live in [`docs/SECURITY.md`](docs/SECURITY.md) and [`docs/PRIVACY.md`](docs/PRIVACY.md).

Contributions are accepted on the understanding that the project will relicense to MIT when it goes open source — by contributing you grant the maintainer the right to include your contribution under that future license.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE): read, use, modify, and share it for any noncommercial purpose; commercial use is reserved while the project incubates. The plan of record is to relicense under MIT at public open-sourcing (see [`docs/decisions/0002-license-polyform-pending-mit.md`](docs/decisions/0002-license-polyform-pending-mit.md)).

> Required Notice: Copyright 2026 Sean Vasey

---

<p align="center"><sub><strong>VASEY/AI</strong> · AI tooling by Sean Vasey · a Vasey Studios project</sub></p>
