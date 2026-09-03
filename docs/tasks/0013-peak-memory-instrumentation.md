# Task: Peak-memory and throughput instrumentation

Status: planned (Milestone 1 audit follow-up, §5).

## Goal
The evaluation report records measured peak resident memory and pixel
throughput for phone-scale and very-long-canvas reconstructions on both CI
platforms, and the audit can cite a number instead of a bound.

## Why it matters
The engine retains every input raster and allocates the complete output
raster; the audit noted that no measured gate verifies the resulting
amplification. Milestone 3's editor and Milestone 7's long-image support
need a baseline to regress against.

## Current behavior
Performance tests prove bounded execution shapes. `EvaluationCaseResult`
carries wall-clock milliseconds only. There is no portable peak-RSS API in
the Swift standard library.

## Required behavior
1. A `PeakMemorySampler` in `TraktionLabEvaluation` reading platform peak RSS
   (`getrusage` `ru_maxrss` on Linux and Darwin, with the documented
   kilobyte/byte unit difference handled explicitly), reported as bytes and
   as a ratio to total input bytes.
2. Two instrumented cases in the standard corpus: phone-scale
   (1170×2532, three captures) and very-long-canvas (ten captures at
   phone width). Their memory and throughput numbers are diagnostic fields,
   not acceptance thresholds — they must not make the gate nondeterministic.
3. A separate advisory threshold (`--max-memory-ratio`) that prints a
   warning; CI does not fail on it until two releases of data exist.
4. The runbook documents how to read the numbers per platform.

## Non-goals
- Preview latency or export throughput (need the editor and export paths).
- Reducing memory use (a later engine task, informed by these numbers).

## Allowed scope
- `Tools/TraktionLab/Evaluation/`, `Tools/TraktionLab/Sources/`
- `Tests/Golden/`, `Tests/Performance/`
- `docs/runbooks/verification.md`, `CHANGELOG.md`, `docs/notes/`,
  `docs/tasks/`

## Forbidden changes
- `Packages/*`, FixtureForge, CI lanes beyond report fields.

## Acceptance criteria
- [ ] Report contains `peakResidentBytes` and `inputAmplification` for the
      two instrumented cases on Linux and macOS.
- [ ] The determinism test still passes (memory fields are excluded from
      the equality check like `milliseconds`).
- [ ] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Writer
Unassigned.

## Reviewer
Independent reviewer required before merge.
