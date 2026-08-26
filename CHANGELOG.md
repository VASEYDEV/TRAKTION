# Changelog

All notable changes to TRAKTION are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Root Swift 6 package with `TraktionDomain`, `TraktionCore`, `TraktionVision`,
  `TraktionUI`, `TraktionAI`, `TraktionLab`, `FixtureForge`, and a macOS SwiftUI preview
  shell.
- Deterministic vertical reconstruction for 2–10 supplied-order, opaque, equal-width
  captures: admissible sampled bounds, budgeted full candidate verification, raw exact
  verification, ambiguity rejection, midpoint/low-difference seam selection, half-open
  reconstruction spans, and one final output allocation.
- Typed failures for unsupported axis, invalid capture count, incompatible width,
  duplicate input, insufficient overlap, ambiguous overlap, invalid plans, and unsafe
  output dimensions.
- Apple ImageIO PNG adapter, `traktion-lab` composite/manifest/joint-diagnostic commands,
  and deterministic `fixture-forge` baseline generation.
- Golden, determinism, repeated-row, typed-failure, performance-shape, and PNG round-trip
  tests plus the tracked Task 0001 acceptance packet.

### Changed

- CI now separates repository policy, Linux Swift core verification, Apple package/PNG
  smoke verification, and a stable required aggregator.
- `scripts/gate.sh` is now the complete macOS build/test/synthetic-PNG gate; portable
  repository and core checks have dedicated scripts.
- SwiftPM `.build/` and `.swiftpm/` local state are ignored.

### Fixed

- Require a unique fully verified overlap placement, preventing a short exact repeated
  band from silently outranking a longer near-exact overlap and duplicating rows.
- Fail with an explicit resource-limit error when the configured budget cannot fully
  verify every still-plausible placement instead of selecting from a partial ranking.

## [0.3.0] - 2026-08-20

### Added

- **TRAKTION Foundation Kit v1 installed at repo root** (owner upload, all 49 files
  sha256-verified against `MANIFEST.json`): canonical agent contract `AGENTS.md`, product
  and architecture spec under `docs/` (PRODUCT, ARCHITECTURE, RECONSTRUCTION_SPEC,
  EDITING_MODEL, EVALUATION, MODEL_POLICY, ROADMAP, PRIVACY, SECURITY, REPO_LAYOUT,
  DEVELOPMENT_WORKFLOW), product ADRs `docs/adr/ADR-001..010`, phased agent prompts
  (`prompts/`), issue/PR templates (`.github/`, `templates/`), and task/review JSON
  schemas (`config/`).
- Repo-governance ADR 0004 recording the kit adoption and reconciliation.

### Changed

- **Product pivot (breaking for docs):** TRAKTION is a native Swift precision
  reconstruction utility — overlapping screenshots, scroll captures, and recording
  frames stitched into one continuous, editable image. The earlier "modular I/O
  prompting for VIZION" concept framing is retired. **Upgrade note:** links to
  `docs/architecture.md` and `docs/flags.md` are gone; see `docs/ARCHITECTURE.md` and
  `docs/PRODUCT.md`.
- `CLAUDE.md` is now the kit's agent-compatibility shim (canonical contract:
  `AGENTS.md`) plus non-canonical repository facts; the v3.0 engineering-standard text
  moved out of the root per the kit's single-policy-layer rule (kept in git history).
- README rewritten to the kit's product statement: design invariants, planned modes,
  confidence states, spec reading order, and Swift/`TraktionLab` stack notes.
- `.gitignore` gains the kit's private/local entries (Xcode state, private fixtures,
  secrets, local diagnostics); `scripts/gate.sh` now also requires `AGENTS.md`.

### Removed

- `TRAKTION_Foundation_Kit_v1.zip` (unpacked; original preserved in git history).
- Concept-stage `docs/architecture.md` (superseded; case-collided with the kit's
  `docs/ARCHITECTURE.md`) and draft-v0 `docs/flags.md` (the kit defines no run-flag
  surface).

## [0.2.0] - 2026-08-20

### Added

- **Run-flag registry, draft v0** (`docs/flags.md` + README "Run flags" table): seven
  traction-named flags (`--trak`, `--grip`, `--drift`, `--steer`, `--lock`, `--tap`,
  `--dry`) mapping 1:1 to the architecture's components, with precedence rules and open
  questions. Design spec only — nothing implemented yet.
- ADR 0002 (license switch) and ADR 0003 (brand hierarchy).

### Changed

- **Brand hierarchy recorded:** VASEY/AI now sits under the forthcoming **Vasey Studios**
  umbrella; README footer and `assets/brand-tokens.md` updated (no Vasey Studios logo in
  this repo until the owner's forthcoming mark lands).
- README "Status & flags" split into a compact status table and the new run-flag
  registry.

- **License replaced: Unlicense → PolyForm Noncommercial 1.0.0** (owner decision,
  [ADR 0002](docs/decisions/0002-license-polyform-pending-mit.md)). TRAKTION is now
  source-available for noncommercial use only while it incubates; the plan of record is a
  relicense to MIT at public open-sourcing. **Upgrade note:** anything obtained from the
  repo before this change remains public domain under the Unlicense; everything from
  0.2.0 onward is PolyForm NC.
- README Contributing section now states the inbound relicense grant (contributions must
  permit the future MIT switch).

## [0.1.0] - 2026-08-20

### Added

- Vasey Multimedia Engineering Standard v3.0 installed at repo root (`CLAUDE.md`) with Project Notes filled for TRAKTION.
- Repository scaffold: `.claude/` (settings, hooks, skills, commands), `.github/workflows/`, `docs/` (architecture, decisions, runbooks, notes), `assets/`, `scripts/`.
- Governance documents: `SECURITY.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `.editorconfig`, `.gitignore`.
- Brand assets: TRAKTION icon and wordmark SVGs plus brand tokens (`assets/`).
- Verification gate for the docs-only stage: `scripts/gate.sh`, run locally and in CI (`.github/workflows/ci.yml`) on every PR and push to `main`.
- First architecture decision record: `docs/decisions/0001-repo-bootstrap.md`.
- Working-notes convention under `docs/notes/` with the bootstrap session note.

### Changed

- README rewritten from a two-line stub to the §8 front-page spec: logo, tagline, badges, status flags, design goals, quick start, and brand footer.

## [0.0.1] - 2026-08-15

### Added

- Initial repository: README stub and the Unlicense.

### Changed

- Project renamed from AKTION to TRAKTION; description updated.
