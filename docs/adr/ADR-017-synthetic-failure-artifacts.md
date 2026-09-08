# ADR-017: Synthetic Failure Artifacts Stay in Lab and Test Tooling

Status: Accepted (task 0012).

## Context

Evaluation and golden assertions previously discarded the rasters and joint
plans needed to inspect a failing run. A typed reconstruction refusal has no
actual image; retaining a fabricated image would misrepresent the evidence.

## Decision

`TraktionLabEvaluation` owns one diagnostic writer used by the evaluation CLI
and golden-test helper. It depends on the existing `TraktionVision` target for
PNG encoding; no third-party dependency or shipping package behavior is added.
The platform stack already provides the codec and `TraktionCore.differenceImage`
provides the absolute RGB difference with opaque alpha.

A bundle has `expected.png`, `actual.png`, `difference.png`, `manifest.json`, and
`joints/joint-NNN.json` plus `joints/joint-NNN-difference.png`. Per-joint captures
are resolved by ID, so shuffled ordering inputs remain correct diagnostics.
The manifest retains the plan, evaluation assessment when available, capture IDs
and dimensions, and synthetic provenance. Input filesystem paths are excluded.

Full expected and actual images are retained without modification. When their
sizes differ, the difference is the absolute difference over their common
top-left extent. The manifest explicitly records both original dimensions,
that extent, and its origin. No padding, blending, annotation, or invented rows
are introduced. Pixels outside that extent remain inspectable in the originals.

When reconstruction refuses, the bundle contains the expected source and a
manifest with the typed failure (or unexpected error). `unavailableArtifacts`
explicitly explains why actual, difference, and joint outputs do not exist.
Unavailable evidence must never be represented by placeholder rasters.

Each case is staged in a fresh temporary directory under the requested root,
then moved into its final location. Existing files, directories, and symlink
entries are refused. Unsafe or duplicate evaluation case names fail before
publication. Any write or cleanup error is surfaced to the caller, and only the
writer's own staging directory may be removed.

## Consequences

- Default evaluation retention includes non-pass verdicts and nondeterminism.
  `--all-artifacts` also retains passing reconstructions and typed refusals.
- Golden tests using `goldenReconstruct` retain their synthetic reconstruction
  evidence until teardown; any assertion failure in those tests writes the
  same bundle when `TRAKTION_GOLDEN_ARTIFACTS` is set. Passing tests write
  nothing. Shared helpers use the XCTest case name to avoid collisions.
  Standard evaluation golden tests pass that environment through explicitly
  with distinct output directories. Ambiguous custom fixtures without a known
  expected source are not wrapped; no expected composite is invented for them.
- Both CI platforms upload only dedicated synthetic directories, only on
  failure. The evaluation JSON report keeps its existing always-upload policy.
- This is diagnostic tooling. Reconstruction gates, source integrity, shipping
  pixel selection, and the evaluation report schema remain unchanged.
