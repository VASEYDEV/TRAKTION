# Task: Evaluation harness with machine-readable metrics report

## Goal
One command runs the standard fixture corpus through the shipping engine and
emits the EVALUATION.md metrics as a deterministic JSON report that CI retains
as an artifact and gates on.

## Why it matters
EVALUATION.md defines the objective quality measures (false-safe rate above
all) but nothing computes them; the Milestone 1 audit (prompt 07) needs
reproducible numbers, not prose.

## Current behavior
Golden tests assert per-fixture behavior pass/fail; no aggregated metrics, no
report artifact, no false-safe/false-warning accounting.

## Required behavior
1. A `TraktionLabEvaluation` library (under `Tools/TraktionLab/`) exposing a
   standard corpus (the task-0003 control-set variants, the 10–80% overlap
   sweep, a horizontal case) and an evaluator producing, per case: outcome vs
   ground-truth expectation, a verdict (`pass`, `false-safe`, `false-warning`,
   `wrong-failure`), pixel equality vs source, missing/duplicated row counts,
   per-joint registration error and seam-difference energy, a determinism check
   (two runs, identical plans and pixels), and wall-clock milliseconds.
2. `traktion-lab evaluate --output <report.json>`: writes the report (sorted
   keys, no timestamps beyond per-case durations), prints a summary, exits
   non-zero when any false-safe, false-warning, wrong-failure, or
   nondeterminism is found.
3. CI (Linux lane) runs the harness and uploads the report as an artifact.
4. Golden tests pin: the standard corpus yields zero false-safes, zero
   false-warnings, all-deterministic; exact fixtures report pixel equality,
   zero missing/duplicated rows, zero registration error, zero seam energy.

## Non-goals
- Engine changes (task 0005 owns those).
- Ordering/OCR/reviewer metrics (later milestones).
- Peak-memory measurement (no portable API; tracked for later).
- Performance benchmarking beyond coarse per-case timing.

## Allowed scope
- `Tools/TraktionLab/`
- `Package.swift` (new library target + test-target dependency)
- `Tests/Golden/`
- `.github/workflows/ci.yml` (evaluation step + artifact upload only)
- `CHANGELOG.md`, `docs/notes/`

## Forbidden changes
- `Packages/TraktionCore/` and `Packages/TraktionVision/` behavior,
  `Tools/FixtureForge/`, gate scripts.

## Inputs / fixtures
Generated in-process from `FixtureControlGenerator` seeds; nothing committed.

## Acceptance criteria
- [x] `traktion-lab evaluate` writes a report that decodes through the public
      Codable model and validates as JSON.
- [x] Standard corpus: 0 false-safe, 0 false-warning, 0 wrong-failure,
      all cases deterministic; command exits 0.
- [x] Exact reconstructable cases report pixelEqualToSource, 0 missing rows,
      0 duplicated rows, 0 registration error, 0 seam energy.
- [x] A fabricated wrong expectation is classified (unit test on the verdict
      logic), proving the gate can actually fail.
- [x] CI uploads the report artifact.
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
