# Task: Order-recovery tooling — lab CLI, smoke, evaluation corpus

## Goal
The task-0008 order-recovery capability is reachable from `traktion-lab`,
covered by the end-to-end smoke gate, and measured by the evaluation
harness, so the Milestone 2 audit has reproducible artifacts.

## Why it matters
An engine capability without CLI reachability, failure-manifest coverage,
and evaluation metrics is invisible to the audit workflow this repository
runs on (prompt 07; EVALUATION.md).

## Current behavior
`traktion-lab reconstruct` consumes inputs strictly in argument order; the
evaluation corpus contains only supplied-order cases; smoke never exercises
ordering.

## Required behavior
1. `traktion-lab reconstruct --recover-order …` recovers the order before
   reconstructing. The success manifest gains `recoveredOrder` (capture IDs
   in recovered order) and `orderRecovered: true`; manifest `schemaVersion`
   becomes 3 (field additive; version bumped because consumers must know
   the field can appear). Failure manifests carry the new
   `ambiguousOrder` / `missingCoverage` codes through the existing typed
   pipeline unchanged.
2. `scripts/smoke.sh` adds: one shuffled-input `--recover-order` run whose
   composite is byte-identical to the supplied-order composite, repeated for
   byte-determinism; and one `--recover-order` failure (missing middle)
   asserting a `missingCoverage` failure manifest.
3. The evaluation harness gains ordering cases (shuffled baseline variants,
   fully reversed input, missing-middle expecting `missingCoverage`), each
   with the standard verdict/determinism accounting; the standard corpus
   stays 0 false-safe, 0 false-warning, all-deterministic.
4. Smoke pins the CLI manifest shape (schemaVersion 3, `orderRecovered`,
   `recoveredOrder`, reordered capture list, plain-run absence of the
   field); golden tests pin the new corpus expectations.

## Non-goals
- FixtureForge changes (shuffles are deterministic in-process permutations
  of generator output).
- New evaluation metrics beyond the existing verdict/accounting model
  (order-quality metrics can follow once Milestone 2 grows evidence types).

## Allowed scope
- `Tools/TraktionLab/`
- `scripts/smoke.sh`
- `Tests/Golden/`
- `CHANGELOG.md`, `docs/notes/`, `README.md` (status only)

## Forbidden changes
- `Packages/*` (task 0008 owns the engine surface), `Tools/FixtureForge/`,
  CI lanes, `scripts/gate.sh`, `scripts/verify-core.sh`,
  `scripts/check-repository.sh`.

## Inputs / fixtures
Generated in-process / in temporary directories by smoke; nothing committed.

## Acceptance criteria
- [x] Shuffled `--recover-order` smoke run produces a byte-identical
      composite to the supplied-order run, twice.
- [x] Missing-middle `--recover-order` smoke run leaves a deterministic
      `missingCoverage` failure manifest.
- [x] `traktion-lab evaluate` passes on the extended corpus with 0
      false-safe / 0 false-warning / 0 wrong-failure and full determinism.
- [x] Smoke asserts manifest schemaVersion 3 plus the recovery fields, and
      that a plain `reconstruct` manifest is unchanged apart from the
      version bump (no `recoveredOrder`, `orderRecovered: false`).
- [x] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Writer
Claude (branch `claude/traktion-dev-setup-f24qtq`)

## Reviewer
Independent reviewer required before merge.
