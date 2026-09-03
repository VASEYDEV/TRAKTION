# Task: Exact-ordering tooling — Lab exposure, smoke, evaluation ordering metrics

## Goal
The task-0007 exact sequence-ordering API is reachable from `traktion-lab`,
covered by the end-to-end smoke gate, and measured by the evaluation harness
with the EVALUATION.md ordering metrics, so Milestone 2 progress has
reproducible artifacts from its first increment onward.

## Why it matters
The Milestone 1 audit (`docs/audits/2026-09-03-milestone-1.md`, §8, item 6)
requires the standard evaluation report to carry ordering metrics before
Milestone 2 can be claimed. Task 0007 deliberately excluded CLI and evaluation
exposure; without them the ordering capability is invisible to the audit
workflow, and near-exact ordering (task 0009) would have no baseline to beat.

## Current behavior
`ReconstructionEngine.reconstructExactUnordered` exists but nothing calls it
outside golden tests. `traktion-lab reconstruct` consumes inputs strictly in
argument order, the evaluation corpus contains only supplied-order cases, and
smoke never exercises ordering.

## Required behavior
1. `traktion-lab reconstruct --order supplied|exact …` (default `supplied`).
   `exact` recovers the order through `reconstructExactUnordered`. Success
   manifests gain `orderPolicy` and, for `exact`, `recoveredOrder` (capture
   IDs in reconstruction order); captures are listed in reconstruction order
   so per-joint diagnostics pair true neighbors. Failure manifests gain
   `orderPolicy` and keep supplied order. Lab manifest `schemaVersion` becomes
   3 (additive fields; version bumped so consumers know they can appear).
2. `scripts/smoke.sh` adds: a shuffled `--order exact` run whose composite is
   byte-identical to the supplied-order composite, repeated for
   byte-determinism; a coverage-gap `--order exact` run that leaves a
   `sequenceOrderNotFound` failure manifest and no composite; and pins the
   plain-run manifest (schemaVersion 3, `orderPolicy: supplied`, no
   `recoveredOrder`).
3. The evaluation harness gains ordering cases — deterministic in-process
   permutations of generator output, no FixtureForge change — each with the
   standard verdict/determinism accounting plus the EVALUATION.md ordering
   metrics in the summary: correct-sequence, duplicate-identification, and
   missing-capture-detection counts and rates. A recovered order that differs
   from the documentary order is a **false-safe** even when the composite
   looks plausible. Report `schemaVersion` becomes 2 with per-case
   `orderPolicy` and `recoveredOrder`.
4. The exact-only boundary is recorded, not hidden: a shuffled near-exact
   (degraded) case is pinned to `sequenceOrderNotFound` and counts against
   the correct-sequence rate. Task 0009 flips that pin.
5. Golden tests pin the new corpus expectations, the ordering summary, and
   the wrong-order false-safe rule; the standard corpus stays 0 false-safe,
   0 false-warning, 0 wrong-failure, all-deterministic.

## Non-goals
- Engine changes (`Packages/`): no new evidence types, no near-exact ordering,
  no failure renames.
- FixtureForge changes; an ordering-ambiguity corpus case needs a repeated
  chrome fixture and lands with task 0010.
- OCR or edge-continuity metrics; peak-memory instrumentation.

## Allowed scope
- `Tools/TraktionLab/`
- `scripts/smoke.sh`
- `Tests/Golden/`
- `README.md`, `CHANGELOG.md`, `docs/tasks/`, `docs/notes/`

## Forbidden changes
- `Packages/*`, `Tools/FixtureForge/`, CI lanes, `scripts/gate.sh`,
  `scripts/verify-core.sh`, `scripts/check-repository.sh`, `AGENTS.md`.

## Inputs / fixtures
Generated in-process (`FixtureControlGenerator`) or in temporary directories
by smoke; nothing committed.

## Acceptance criteria
- [x] Shuffled `--order exact` smoke run produces a byte-identical composite
      to the supplied-order run, twice.
- [x] Coverage-gap `--order exact` smoke run leaves a deterministic
      `sequenceOrderNotFound` failure manifest and no composite.
- [x] Plain `reconstruct` manifest is unchanged apart from the version bump
      and `orderPolicy: supplied`; an invalid `--order` value is a usage error.
- [x] `traktion-lab evaluate` passes on the extended corpus with 0
      false-safe / 0 false-warning / 0 wrong-failure and full determinism,
      and the summary reports the ordering metrics.
- [x] A fabricated wrong recovered order classifies as false-safe (unit test
      on the verdict logic).
- [x] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Required evidence
- command output
- `/tmp/evaluation-report.json` with the `ordering` summary
- smoke output including the ordering sections

## Writer
Claude (branch `claude/repo-status-handoff-hfsjyv`)

## Reviewer
Independent reviewer required before merge.
