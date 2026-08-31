# 2026-08-31 — Milestone 1 corpus: failure manifests + fixture control set

Writer session executing tasks 0002 and 0003 (phase B of the post-foundation
plan) on `claude/traktion-dev-setup-f24qtq`, on top of the merged PR #4 + #5
foundation.

## Task 0002 — typed failure manifests

- `ReconstructionFailure` is now `Codable` and exposes `code`, a stable wire
  string per case (shared by lab manifests and fixture ground truth).
- `traktion-lab reconstruct` writes a `status: failed` manifest on any typed
  decode or reconstruction failure (stage, failureCode, description, typed
  failure, captures decoded so far, input names); success manifests carry
  `status: reconstructed`; `schemaVersion` 2. Publication IO failures keep the
  reviewed clean-and-retry behavior — no failure manifest there, by design.
- Smoke asserts both stages, content via python JSON checks (formatting-proof
  across Foundation implementations), and byte-identical repeat runs.

## Task 0003 — control set

`FixtureControlGenerator` in FixtureForgeKit + `fixture-forge generate`.
Ground truth separates `expectedStatus` (semantic, stable across milestones)
from `expectedFailureCode` (what today's engine must do). Empirical pins from
running every variant through the engine:

| variant           | engine today                                | note |
|-------------------|---------------------------------------------|------|
| baseline          | reconstructs exactly                        | also 10–80% overlap sweep |
| one-pixel-offset  | reconstructs, jittered overlaps recovered   | interior origins only — jittering the last origin shrinks coverage (first design error, caught by the golden) |
| degraded (±2)     | reconstructs, all joints `strong`           | rows verbatim from contributing captures |
| duplicate-capture | `duplicateCapture` (nonadjacent)            | |
| reversed-order    | `insufficientOverlap`                       | M2 will diagnose reversal |
| missing-middle    | `insufficientOverlap`                       | M2: missing coverage |
| sticky-header/footer | `insufficientOverlap`                    | M4 recovers occluded content |
| floating-control  | `insufficientOverlap`                       | M4 |
| scrollbar         | **reconstructs** with thumb artifacts       | faithful to capture pixels (row-verbatim asserted); cosmetics are M4 — not a false-safe |
| any horizontal    | `unsupportedAxis`                           | |

The scrollbar outcome is the one judgment call: the engine stitches truthfully
(every output row is byte-identical to its contributing capture), so the pin is
"reconstructable-with-scrollbar-artifacts" rather than a forced failure.

## Verification (Linux, Swift 6.1.2)

`bash scripts/check-repository.sh` PASS · `bash scripts/verify-core.sh` PASS
(59 tests, 0 failures) · `bash scripts/smoke.sh` PASS (incl. new
failure-manifest stages). Apple lane runs in CI on the PR.
