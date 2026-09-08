# Task: Golden-failure CI artifact bundle

Status: implemented and independently reviewed; required CI pending.

## Goal
When a golden or evaluation case fails in CI, the run retains the bundle
`docs/EVALUATION.md` prescribes: expected image, actual image, absolute
difference image, reconstruction manifest, and per-joint diagnostics.

## Why it matters
A pixel-mismatch assertion alone makes a reviewer reproduce the failure before
seeing the affected rows. Synthetic evidence should survive the original run.

## Implemented behavior
1. `traktion-lab evaluate --artifacts-dir <dir>` writes non-pass verdicts and
   nondeterministic outcomes under `<dir>/<case-name>/`. Passing cases write
   nothing by default; `--all-artifacts` also retains passing reconstructions
   and typed refusals. CLI validation rejects missing, unknown, or duplicate
   options and requires an artifact directory with `--all-artifacts`.
2. Reconstructed bundles contain `expected.png`, `actual.png`,
   `difference.png`, `manifest.json`, and per-joint JSON/difference PNGs under
   `joints/`. Diagnostics resolve neighboring captures by their IDs, including
   shuffled input sequences.
3. The difference image uses the shipping `differenceImage` implementation:
   absolute RGB channel differences and opaque alpha. Dimension mismatches
   preserve both complete rasters and compare the common top-left extent,
   recorded explicitly in the manifest.
4. Typed refusals retain the expected source and failure manifest. When the
   engine produced no actual image or joints, the manifest marks those outputs
   unavailable rather than fabricating them. Unexpected errors remain visible.
5. Golden helpers retain synthetic reconstruction evidence through XCTest
   teardown. When any assertion fails and `TRAKTION_GOLDEN_ARTIFACTS` is set,
   they write the same bundle. This covers pixel, plan, ordering, confidence,
   determinism, and unexpected reconstruction failures for wrapped cases.
   Evaluation golden tests explicitly forward the same environment.
6. CI supplies dedicated synthetic output directories in both Linux and Apple
   test lanes. Linux evaluation also supplies `--artifacts-dir`. Bundle uploads
   use `if: failure()`; the existing JSON report still uploads with `always()`.
7. Publication stages a new directory and refuses pre-existing output entries,
   including symlinks. Unsafe/duplicate evaluation case names fail before
   writing. Write and cleanup errors propagate; source files are never removed.

## Non-goals
- Image viewers, HTML reports, or thumbnails.
- Changes to failure classification, gate semantics, or shipping pixels.
- Private captures or remote model calls.

## Allowed scope
- `Tools/TraktionLab/`, `Tests/Golden/`, `.github/workflows/ci.yml`
  (artifact arguments/environment and upload steps), `scripts/verify-core.sh`
  (env pass-through only; no edit needed because environment already inherits).
- `Package.swift`: existing internal target edges to `TraktionVision`, needed
  to share its existing PNG codec with Lab evaluation and contract tests.
  No external dependency is introduced.
- `docs/adr/ADR-017-synthetic-failure-artifacts.md`, this task packet, and parent
  reconciliation of verification/task/roadmap/session documentation.

## Forbidden changes
- `Packages/*` behavior, FixtureForge, or gate semantics.

## Acceptance criteria
- [x] Fabricated pixel mismatch produces complete decoded-valid bundle with
      precise absolute difference and per-joint diagnostics.
- [x] Passing selected corpus writes nothing unless all-artifacts is enabled.
- [x] False-safe and false-warning outcomes publish evidence without invented
      rasters; unavailable outputs are explicit.
- [x] Dimension mismatch, output collision, symlink preservation, unsafe names,
      duplicate names, and late publication failure have regression coverage.
- [x] Golden helper uses the shared bundle writer only when enabled and failed.
- [x] CI uploads bundles only on failure and from synthetic-only paths.
- [x] Full current-branch suite (102 tests) and standard corpus (43 cases) pass.
- [ ] Integrated branch with task 0014 passes required CI.
- [x] Independent review completed; input-recording and helper-name findings fixed.
- [ ] Required CI passes before merge.

## Fixtures and tests
`SyntheticArtifactTests` uses deterministic generated fixtures only. Tests
fabricate a one-channel pixel mismatch, unexpected axis refusal, incorrect
ordering expectation, dimension mismatch, unavailable capture diagnosis,
filesystem collision, and unexpected error. Existing golden assertions are
preserved; the helper changes retention, never what counts as success.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json --artifacts-dir /tmp/evaluation-artifacts
swift run traktion-lab evaluate --output /tmp/evaluation-all.json --artifacts-dir /tmp/evaluation-all --all-artifacts
```

## Required evidence / handoff
- Focused artifact contracts, complete tests, standard corpus, and CLI bad-option
  probes; report exact commands and any environment-only toolchain adaptation.
- Independent reviewer: inspect ID-based joint lookup, refusal metadata, common
  difference extent, collision handling, and synthetic-only CI upload paths.
- ADR-017 records the internal dependency and truthful absence/dimension policy.

## Writer
Codex, branch `codex/golden-failure-artifacts`, sole writer for this packet.

## Reviewer
Independent reviewer required before merge; coordinated by the parent session.

## Local verification evidence

Swift 6.0.3 on Linux. The workspace's SwiftPM subprocess monitor can crash with
SIGILL while reading `/proc`; this also reproduces on unchanged main. No source
or CI gate workaround was committed. The integrated driver builds successfully;
running the built XCTest binary avoids that monitor. Release optimization was
used for the complete suite to keep phone-scale/evaluation execution bounded.

- `bash scripts/check-repository.sh`: PASS.
- `git diff --check`: PASS.
- `swift test --use-integrated-swift-driver -j 2 --filter SyntheticArtifactTests`:
  initial debug run PASS, 9 tests. Later SwiftPM-supervised test attempts hit
  the environment monitor failure, so final verification used direct XCTest.
- `swift build --configuration release --build-tests --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing`:
  PASS. `-enable-testing` is needed for existing `@testable` imports in release.
- `TRAKTION_GOLDEN_ARTIFACTS=/tmp/traktion-task0012-release-artifacts-final .build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest`:
  PASS, all 102 official tests, zero failures. No temporary probe in discovery.
- Release `traktion-lab evaluate --output /tmp/traktion-task0012-evaluation-report.json --artifacts-dir /tmp/traktion-task0012-evaluation-artifacts`:
  PASS, 43 cases; no artifacts directory created.
- Release `traktion-lab evaluate --all-artifacts --artifacts-dir /tmp/traktion-task0012-all-artifacts --output /tmp/traktion-task0012-evaluation-all.json`:
  PASS, exactly 43 bundles; original/refusal/joint file coverage checked.
- Eight malformed or overlapping CLI requests: all exit 1, nothing written.
- Temporary intentional XCTest probe: two failing tests called one shared
  helper; both wrote complete, distinct case bundles through actual teardown.
  Probe source was removed before the final production test build and is not
  committed. These intentional failures are separate from the passing suite.

The unmodified CI `verify-core.sh` gate remains required before merge. Apple
ImageIO behavior still requires the Apple CI lane; local checks used Linux's
existing pure-Swift PNG implementation.
