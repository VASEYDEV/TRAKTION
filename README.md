<p align="center">
  <img src="assets/traktion-icon.svg" alt="TRAKTION logo — an amber badge with a white letter T marked with tire-tread notches" width="128">
</p>

<h1 align="center">TRAKTION</h1>

<p align="center"><strong>Precision reconstruction for content captured in pieces — Be Right on TRAK.</strong></p>

<p align="center">
  <a href="https://github.com/vaseydev/traktion/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/vaseydev/traktion/ci.yml?branch=main&label=gate" alt="CI gate status"></a>
  <img src="https://img.shields.io/badge/version-0.4.0--dev-blue" alt="Version 0.4.0 development">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-crimson" alt="License: PolyForm Noncommercial 1.0.0">
  <img src="https://img.shields.io/badge/status-experimental-orange" alt="Status: experimental">
</p>

## What is TRAKTION?

TRAKTION is a precision reconstruction utility that turns overlapping screenshots, scroll captures, screen-recording frames, and related visual fragments into **one continuous, editable image** — restoring content captured in pieces back into the continuous form in which it originally existed.

Full-page capture often fails: content scrolls inside nested frames, headers stay fixed, floating controls cover content, or the source app simply has no full-page capture. Manual stitching is slow because every adjacent capture overlaps and must be aligned and trimmed precisely. TRAKTION's deterministic reconstruction engine does that alignment — and reports what it cannot prove instead of inventing it.

## Status

**Milestone 1 has measured evidence; Milestone 2 and native app development are in progress.** The deterministic reconstruction core, synthetic fixture generator, diagnostic CLI, golden tests, cross-platform PNG adapters, evaluation harness, and minimal SwiftUI shell are implemented. Tasks 0012–0014 address the diagnostic and memory evidence identified by the [2026-09-03 milestone audit](docs/audits/2026-09-03-milestone-1.md). The Xcode iOS target has a required simulator build/install/launch test; device signing and usable import/editor/export flows remain separate work. Every tracked task and its verification status is in the [task index](docs/tasks/README.md).

| Current capability | State |
| --- | --- |
| Supplied-order vertical reconstruction | Implemented for 2–10 opaque, equal-width PNG captures |
| Automatic sequence ordering | Exact (`--order exact`, ADR-014) and near-exact (`--order near-exact`, ADR-015) recovery in the core and the Lab; both reject missing or ambiguous ordering evidence; near-exact pixel similarity alone does not prove documentary continuity |
| Exact suffix/prefix overlap and seam plan | Implemented with ambiguity rejection |
| Decoded-pixel golden comparison | Implemented for deterministic synthetic fixtures |
| Machine-readable evaluation gate | Implemented for the standard 45-case corpus, including ordering metrics and diagnostic memory/throughput baselines |
| Composite, manifest, and joint diagnostics | Implemented in `traktion-lab`; evaluation/golden failure bundles are retained in CI |
| Horizontal, sticky UI, video, web capture | Later milestones; fail or remain disabled. Identical top-and-bottom chrome is rejected by task 0010; general fixed-element recovery remains unimplemented |
| Native application | Xcode iOS target and shared simulator scheme implemented (task 0016); required simulator CI verifies the read-only shell. Device signing and import/editor/export flows remain |

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

The platform-neutral core uses Swift 6. PNG I/O uses Apple ImageIO on macOS and a deterministic pure-Swift codec elsewhere, behind one contract ([ADR-011](docs/adr/ADR-011-imageio-boundary-pure-swift-fallback.md)) — so the end-to-end PNG smoke runs on any host, and `gate.sh` on macOS additionally verifies the ImageIO path.

```bash
git clone https://github.com/vaseydev/traktion.git
cd traktion
bash scripts/check-repository.sh  # repository policy on any host
bash scripts/verify-core.sh       # Swift build + tests on any host
bash scripts/smoke.sh             # fixture → reconstruct → compare on any host
swift run --configuration release traktion-lab evaluate --output /tmp/evaluation-report.json
bash scripts/gate.sh              # complete macOS gate (adds ImageIO verification)
bash scripts/verify-ios.sh        # macOS/Xcode: dedicated simulator build/install/launch/UI tests
```

Generate and reconstruct the baseline fixture:

```bash
swift run fixture-forge baseline --output-dir /tmp/traktion-fixture
swift run traktion-lab reconstruct \
  --output /tmp/traktion-composite.png \
  /tmp/traktion-fixture/capture-001.png \
  /tmp/traktion-fixture/capture-002.png \
  /tmp/traktion-fixture/capture-003.png
swift run traktion-lab compare \
  /tmp/traktion-fixture/source.png \
  /tmp/traktion-composite.png
```

The Lab writes a reconstruction JSON sidecar plus per-joint JSON and absolute-difference PNGs. It refuses to overwrite outputs or turn unsupported/ambiguous evidence into a successful composite.

For the native app, open `App/TRAKTION.xcodeproj` and use its shared `TRAKTION`
scheme with an iPhone simulator. The [iOS runbook](docs/runbooks/ios-development.md)
documents CI reproduction, test evidence, and developer-owned device signing.

Captures whose order is unknown can be ordered from byte-exact evidence (`--order exact`) or from uniquely registered near-exact overlaps (`--order near-exact`); missing or ambiguous ordering evidence is a typed failure:

```bash
swift run traktion-lab reconstruct --order exact \
  --output /tmp/traktion-recovered.png \
  /tmp/traktion-fixture/capture-002.png \
  /tmp/traktion-fixture/capture-003.png \
  /tmp/traktion-fixture/capture-001.png
```

## Tech stack & environment

- **Stack:** Swift 6, SwiftPM and Xcode, shared native SwiftUI shell, Apple ImageIO PNG boundary, dependency-free platform-neutral reconstruction core ([ADR-001](docs/adr/ADR-001-native-swift.md)).
- **Environment variables:** verification supports `TRAKTION_SMOKE_DIR` for synthetic smoke output and `TRAKTION_GOLDEN_ARTIFACTS` for opt-in test failure evidence; see the [verification runbook](docs/runbooks/verification.md). No runtime secrets or model API are needed.
- **Architecture:** module boundaries and data flow in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); layout in [`docs/REPO_LAYOUT.md`](docs/REPO_LAYOUT.md).

## Notes & updates

- [`CHANGELOG.md`](CHANGELOG.md) — every meaningful change (Keep a Changelog + SemVer).
- [`docs/notes/`](docs/notes/) — dated working notes (`YYYY-MM-DD-topic.md`).
- [`docs/adr/`](docs/adr/) — product/architecture ADRs · [`docs/decisions/`](docs/decisions/) — repo-governance ADRs.
- [`docs/tasks/`](docs/tasks/README.md) — tracked task packets with status; [`docs/ROADMAP.md`](docs/ROADMAP.md) — milestone status.

## Contributing

[`AGENTS.md`](AGENTS.md) is the canonical contract for all contributors and coding agents. Conduct is governed by the [Code of Conduct](CODE_OF_CONDUCT.md); vulnerabilities go through the [security policy](SECURITY.md), not public issues — the app's own security and privacy constraints live in [`docs/SECURITY.md`](docs/SECURITY.md) and [`docs/PRIVACY.md`](docs/PRIVACY.md).

Contributions are accepted on the understanding that the project will relicense to MIT when it goes open source — by contributing you grant the maintainer the right to include your contribution under that future license.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE): read, use, modify, and share it for any noncommercial purpose; commercial use is reserved while the project incubates. The plan of record is to relicense under MIT at public open-sourcing (see [`docs/decisions/0002-license-polyform-pending-mit.md`](docs/decisions/0002-license-polyform-pending-mit.md)).

> Required Notice: Copyright 2026 Sean Vasey

---

<p align="center"><sub><strong>VASEY/AI</strong> · AI tooling by Sean Vasey · a Vasey Studios project</sub></p>
