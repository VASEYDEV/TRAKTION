# Changelog

All notable changes to TRAKTION are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Automatic order recovery** (task 0006, ADR-014, Milestone 2): the engine
  recovers the documentary order of an unordered 2–10 capture set from the
  pairwise overlap graph — `recoverOrder` returns the order plus per-junction
  evidence, `reconstructRecoveringOrder` re-verifies it through the reviewed
  supplied-order pipeline. The order must be uniquely provable: several
  acceptable orders refuse with the new typed `ambiguousOrder` (deterministic
  candidate sample + exact count), an unconnectable set refuses with
  `missingCoverage` (longest chain + unconnected captures), pair-level
  ambiguity contributes no edge, and any probe budget exhaustion fails the
  whole recovery. Supplied-order behavior is byte-identical (the registration
  path was refactored, not changed). Goldens: shuffled and fully reversed
  sets reconstruct pixel-identically; symmetric content refuses with both
  orders listed; periodic content still refuses; tiny budgets fail closed.
- **Order-recovery tooling** (task 0007): `traktion-lab reconstruct
  --recover-order` (manifest schemaVersion 3 with `orderRecovered` /
  `recoveredOrder`, captures listed in reconstruction order), smoke coverage
  (shuffled run byte-identical to supplied-order, deterministic across runs;
  missing-middle leaves a typed `missingCoverage` failure manifest), and
  three ordering cases in the evaluation corpus (19 total) with a
  recovered-order-mismatch false-safe rule; report schemaVersion 2 adds
  `recoveredOrder` per case.

- **Evaluation harness** (task 0004): `traktion-lab evaluate --output <report.json>`
  runs the standard corpus (all control-set variants, the 10–80% overlap sweep, a
  horizontal case) and emits the EVALUATION.md metrics — per-case verdicts with
  false-safe/false-warning/wrong-failure accounting, pixel equality, missing and
  duplicated row counts, per-joint registration error and seam energy, and a
  two-run determinism check — exiting non-zero on any unacceptable summary. The
  Linux CI lane runs it and uploads the report artifact.
- **Adaptive early-exit candidate verification** (task 0005, ADR-013): when the
  sparse sampling pass cannot discriminate candidates, each survivor is scanned at
  full width in edge-energy row order with early exit the moment its running lower
  bound exceeds an acceptance threshold. Phone-scale (1170×2532) and large sparse
  captures now reconstruct within default budgets where the engine previously
  failed closed with `resourceLimitExceeded`; `refinementRounds: 1` preserves the
  original algorithm byte for byte. Golden proofs: the same 400×800 input fails
  closed single-pass and reconstructs exactly under refinement; genuine periodic
  ambiguity still refuses; suite now 67 tests.

### Changed

- Default registration budgets recalibrated to measured phone-scale cost:
  `maximumSampleComparisonsPerJoint` 32M → 128M,
  `maximumFullComparisonPixelsPerJoint` 32M → 64M (docs/tasks/0005).

- **Typed failure manifests** (task 0002): a failed `traktion-lab reconstruct` now
  writes a deterministic `status: failed` manifest — stage (`decode`/`reconstruct`),
  stable `failureCode`, human-readable description, the typed `ReconstructionFailure`
  (now `Codable`, with a `code` wire contract), captures decoded before the failure,
  and all input names. Success manifests gain `status: reconstructed`; lab manifest
  `schemaVersion` is now 2. Publication (IO) failures keep clean-retry behavior.
- **FixtureForge control set** (task 0003, prompt 02): configurable deterministic
  generation (`fixture-forge generate --scenario …`) of duplicate-capture,
  reversed-order, missing-middle, sticky-header, sticky-footer, floating-control,
  scrollbar, one-pixel-offset, and degraded fixtures — plus horizontal-axis
  generation — each with Codable ground truth recording semantic status,
  the failure code today's engine must return, capture origins, expected order,
  overlaps, and a platform-independent source-pixel fingerprint.
- **Adversarial golden coverage** (`Tests/Golden/FixtureControlSetTests.swift`,
  16 tests; suite now 59): every adversarial variant ends in its pinned typed
  failure with no composite; positive controls (baseline, one-pixel offset,
  degraded, 10–80% overlap sweep) reconstruct with expected overlaps and
  row-verbatim output. Empirically pinned: the scrollbar variant reconstructs
  faithfully (thumb artifacts preserved verbatim; scrollbar handling is
  Milestone 4), while sticky chrome and floating controls fail closed with
  `insufficientOverlap`. Smoke now exercises both failure-manifest stages and
  their byte-determinism.

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
- **Pure-Swift fallback PNG codec** behind the unchanged `PNGCodec` contract on non-Apple
  hosts (full RFC-1951 inflate, all five filters, stored-block encode; opaque-only, same
  typed errors and pixel limit), so Linux runs the complete decode → reconstruct → encode
  → compare path. Cross-backend parity and CPython-zlib interop vectors pinned by
  `Tests/Unit/TraktionVisionPureCodecTests` and `Tests/Integration/PNGCodecParityTests`.
- **Schema-aligned semantic-review contract:** `VisualReviewDecision` now mirrors
  `config/visual-review-decision.schema.json` (action, classification, confidence,
  abstain, reasonCode, …) with disabled and mock adapters and contract tests; still
  protocol/adapters only, no provider SDK.
- ADR-011 (ImageIO boundary with pure-Swift fallback) and ADR-012 (unique acceptable
  translation, ratifying the RECONSTRUCTION_SPEC edit), closing the process findings of
  the PR #4 independent review; session note
  `docs/notes/2026-08-31-foundation-review-and-adaptation.md`.

### Changed

- CI now separates repository policy, Linux Swift core verification, Apple package/PNG
  smoke verification, and a stable required aggregator.
- `scripts/gate.sh` is now the complete macOS build/test/synthetic-PNG gate; portable
  repository and core checks have dedicated scripts.
- `scripts/smoke.sh` runs on any host (Apple ImageIO on Darwin, the pure-Swift codec
  elsewhere), and the Linux CI lane now runs it end to end after core verification.
- SwiftPM `.build/` and `.swiftpm/` local state are ignored.

### Fixed

- Require a unique fully verified overlap placement, preventing a short exact repeated
  band from silently outranking a longer near-exact overlap and duplicating rows.
- Fail with an explicit resource-limit error when the configured budget cannot fully
  verify every still-plausible placement instead of selecting from a partial ranking.
- Detect byte-identical captures anywhere in a supplied sequence and accept a valid
  full-height prefix overlap when the following capture extends the document.
- Create explicit diagnostics paths recursively and remove partial Lab artifacts after
  any failed publication so the same command can be retried safely.

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
