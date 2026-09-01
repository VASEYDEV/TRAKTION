# Task: Adaptive candidate refinement for realistic capture scale

## Goal
Registration succeeds within default budgets on realistic phone-scale and
sparse-content captures, without weakening the unique-acceptable-translation
rule (ADR-012) or any fail-closed budget semantics.

## Why it matters
The merged foundation documents (PR #4) that its one-pass sampled lower bounds
can leave many candidates plausible on large, weakly discriminated inputs, so
the bounded verifier returns `resourceLimitExceeded` instead of reconstructing.
That is safe but makes the engine refuse ordinary screenshots with quiet
regions — the last engine blocker for the Milestone 1 audit.

## Current behavior
`ReconstructionEngine.register` samples every overlap candidate once at fixed
density (`sampledRows` × `sampledColumns`), keeps every candidate whose lower
bound is under the acceptance thresholds, and full-verifies all of them —
failing closed when survivors exceed `candidateLimit` or the pixel budget.

## Required behavior
1. Adaptive verification: when the first sampling pass leaves more survivors
   than `candidateLimit`, each survivor is scanned at full width with rows in
   descending edge-energy order of the following capture, early-exiting the
   moment its running (always-true) lower bound exceeds a threshold; a
   completed scan yields the exact score. (Density-scaling refinement rounds
   were prototyped and rejected — the bound arithmetic requires
   ~threshold-fraction coverage of each candidate's area regardless, and the
   early-exit scan pays it only where needed; see ADR-013.)
2. `ReconstructionSettings.refinementRounds` (default 3, minimum 1);
   `refinementRounds: 1` reproduces the pre-change algorithm exactly, values
   of 2 or more enable the verification pass. Default budgets recalibrated to
   measured phone-scale cost (sample 128M, full-comparison 64M).
3. Unchanged: the unique-acceptable rule, full-pixel verification of every
   survivor, `resourceLimitExceeded` when survivors still exceed the candidate
   or pixel budgets, all overflow-safe budget accounting, determinism.
4. ADR-013 records the proof-strategy change.

## Non-goals
- Threshold changes (`maximumNormalizedMeanAbsoluteError` etc. untouched).
- Subpixel or affine registration; ordering; sticky-element recovery.
- Removing any fail-closed path.

## Allowed scope
- `Packages/TraktionCore/Sources/TraktionCore/`
- `Tests/Golden/`, `Tests/Performance/`
- `docs/adr/ADR-013-*.md`, `CHANGELOG.md`, `docs/notes/`

## Forbidden changes
- `Packages/TraktionDomain/` contracts, `Packages/TraktionVision/`, tools,
  CI, gate scripts.

## Inputs / fixtures
- Regression trap: a sparse-content pair (large quiet regions, text lines)
  sized so one-pass sampling leaves > `candidateLimit` plausible candidates.
- Phone-scale baseline: 1170×2532 captures via `FixtureControlGenerator`.

## Acceptance criteria
- [x] Sparse-content pair: `refinementRounds: 1` returns
      `resourceLimitExceeded`; default settings reconstruct it exactly.
- [x] Phone-scale baseline reconstructs under default settings.
- [x] Every existing test passes unchanged (61-test suite), including the
      periodic-ambiguity and candidate-budget fail-closed goldens.
- [x] Two runs produce identical plans and output pixels.
- [x] ADR-013 committed.
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
Independent reviewer required before merge (engine change: prioritize
false-safe review per AGENTS.md).
