# Task: FixtureForge full control set and adversarial golden corpus

## Goal
FixtureForge generates the prompt-02 control set deterministically, each fixture
carries machine-readable ground truth including the behavior today's engine must
exhibit, and golden tests pin that behavior.

## Why it matters
Golden fixtures are the reconstruction quality authority (ADR-005). Milestone 1
cannot be audited (prompt 07) until the EVALUATION.md fixture families exist and
every adversarial case provably ends in a typed failure rather than silent
documentary corruption.

## Current behavior
`FixtureForgeKit.SyntheticFixtureFactory` offers fixed scenarios (baseline,
exact-two, repeated-rows, large, unrelated/width-mismatch/duplicate pairs); the
`fixture-forge` CLI emits only `baseline`; the fixture manifest is a private
struct in the CLI, write-only.

## Required behavior
1. A public `FixtureForgeKit` configuration API: source dimensions, axis
   (horizontal generation allowed; engine support is not), viewport length,
   capture count, overlap rows or ratio, seed, and a variant:
   `baseline`, `duplicateCapture`, `reversedOrder`, `missingMiddle`,
   `stickyHeader`, `stickyFooter`, `floatingControl`, `scrollbar`,
   `onePixelOffset`, `degraded`.
2. A public, Codable fixture manifest (source ID, axis, dimensions, capture IDs
   and origins, expected order, expected overlaps, and a platform-independent
   source-pixel fingerprint — encoded PNG bytes differ per codec backend, so
   the fingerprint hashes raw RGBA instead) extended with
   `expectedStatus` (semantic, e.g. `"reconstructable"`, `"reversed-order"`)
   and `expectedFailureCode` (what the current engine must return; null when
   reconstructable). Writer emits PNGs + `fixture.json`; identical configuration
   yields byte-identical output.
3. CLI: `fixture-forge generate --scenario <variant> --output-dir <dir>` with
   optional dimension/seed/overlap flags. The existing `baseline` subcommand and
   the existing factory scenario functions keep their current output byte for
   byte (the reviewed golden tests must not need changes).
4. Golden tests (`Tests/Golden/`) for every variant: reconstructable variants
   assert plan overlaps/origins and composite correctness; adversarial variants
   assert the exact typed failure and that no composite is produced. Include an
   overlap sweep across roughly 10–80% ratios on the baseline shape.
5. Empirically pinned expectations: sticky header/footer, floating control, and
   scrollbar expectations are recorded from observed engine behavior only if
   that behavior is safe (typed failure or provably correct composite). A silent
   wrong composite is a defect finding, not an expectation — surface it, do not
   encode it.

## Non-goals
- Engine changes (registration, thresholds, seams). If a variant exposes a
  false-safe, report it; fixing it is a separate task.
- Horizontal reconstruction support.
- Sticky-element recovery (Milestone 4), OCR, reordering (Milestone 2).
- Committed binary fixture corpora (manifests + regeneration stay the policy).

## Allowed scope
- `Tools/FixtureForge/`
- `Tests/Golden/`, `Tests/Unit/`
- `scripts/smoke.sh` (only if a scenario is added to smoke)
- `CHANGELOG.md`, `docs/notes/`, `Package.swift` (test target wiring if needed)

## Forbidden changes
- `Packages/TraktionCore/`, `Packages/TraktionVision/` behavior,
  `Tools/TraktionLab/` (task 0002 owns it), CI workflow semantics.

## Inputs / fixtures
Generated in-test from seeds; no committed binaries.

## Acceptance criteria
- [x] Every variant generates deterministically (double-generation byte equality).
- [x] `fixture.json` round-trips through the public Codable manifest.
- [x] Reconstructable variants (baseline shapes, one-pixel offset, degraded)
      reconstruct with expected overlaps; degraded yields `strong` joints.
- [x] Duplicate, reversed, missing-middle, sticky-header, sticky-footer, and
      floating-control variants each end in the pinned typed failure with no
      composite. Scrollbar empirically reconstructs faithfully (thumb pixels
      preserved row-verbatim from the contributing capture — not a false-safe);
      pinned as `reconstructable-with-scrollbar-artifacts` per criterion 5.
- [x] Overlap sweep passes across the 10–80% range.
- [x] Existing factory scenarios and `fixture-forge baseline` output unchanged.
- [x] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
```

## Writer
Claude (branch `claude/traktion-dev-setup-f24qtq`)

## Reviewer
Independent reviewer required before merge.
