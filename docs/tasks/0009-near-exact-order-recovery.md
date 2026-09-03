# Task: Near-exact order recovery on the exact-ordering contract

Status: planned (next engine task). Prior art: PR #8
(`claude/traktion-dev-setup-f24qtq`, commits `4248c00`/`ce43247`) implemented
this design against the pre-audit `main`; it is superseded by the merged
task-0007 contract and must be **ported, not merged** (see
`docs/notes/2026-09-03-handoff-review-and-ordering-tooling.md`).

## Goal
Recover the documentary order of an unordered 2–10 capture set from
near-exact (threshold-accepted, uniquely registered) pairwise evidence, under
a global uniqueness proof, without changing the exact-only entry point or the
supplied-order pipeline byte for byte.

## Why it matters
Task 0007 orders only byte-exact captures; any lossy capture pipeline
(the `degraded` control, real device screenshots re-encoded by messaging
apps) currently fails `sequenceOrderNotFound` even when every pair registers
uniquely. ADR-014 reserved this for "a later task with a global uniqueness
proof". The evaluation report's `ordering.correctSequenceRate` records the
gap this task closes.

## Current behavior
`reconstructExactUnordered` builds edges from byte-exact suffix/prefix
overlaps only. `register` throws on pair-local rejections, so it cannot be
used as a graph probe without catching typed failures.

## Required behavior
1. Refactor `register` into an outcome-returning `probePair`
   (accepted / insufficientOverlap / ambiguousOverlap) plus a throwing
   wrapper that maps outcomes back to the identical typed throws at the
   identical decision points. Duplicate captures and every budget
   exhaustion still throw. Supplied-order behavior must be byte-identical
   (the whole existing suite passes unchanged).
2. A near-exact ordering entry point (`reconstructUnordered` with an
   evidence policy, or a sibling of `reconstructExactUnordered` — writer's
   choice, recorded in the ADR) that probes every directed pair with the
   unchanged registration pipeline (ADR-012 uniqueness, ADR-013 early exit,
   per-joint budgets), creates an edge only for `accepted`, and requires
   exactly one directed path covering every capture.
3. Global uniqueness: count complete paths exactly (subset dynamic
   programming, bounded by 10!); more than one path returns
   `ambiguousSequenceOrder` with the first two orders in the stable
   capture-identity traversal order; none returns `sequenceOrderNotFound`.
   Existing failure codes and payload shapes are reused unchanged — do not
   add `ambiguousOrder`/`missingCoverage` twins. Longest-chain diagnostics,
   if wanted, go in a result/manifest field, not in the failure payload.
4. Bound total probe work: per-pair budgets as today plus a whole-recovery
   accounting (n ≤ 10 → at most 90 probes) that fails the entire recovery
   with `resourceLimitExceeded` before selecting from a partial graph.
5. Replay the recovered order through supplied-order `reconstruct` so final
   plan and pixels are produced and re-verified by the Milestone 1 path.
6. Determinism: identical inputs yield identical orders and failure
   payloads for any input permutation.
7. Tooling: `traktion-lab reconstruct --order near-exact`; the evaluation
   corpus flips `order-degraded-exact-only` to a reconstruct expectation
   (rename it) and adds the symmetric-content ambiguity case once task 0010
   provides the fixture.
8. ADR-015 records the rule and the solver design (ADR-014 stays accepted
   for the exact-only path).

## Non-goals
- OCR-continuation or geometry-prior edge scoring.
- Tolerant near-duplicate handling (byte-identical duplicates remain
  `duplicateCapture`).
- Horizontal ordering; subpixel or affine registration.

## Allowed scope
- `Packages/TraktionDomain/Sources/TraktionDomain/`
- `Packages/TraktionCore/Sources/TraktionCore/`
- `Tools/TraktionLab/`, `scripts/smoke.sh`
- `Tests/Golden/`, `Tests/Unit/`
- `docs/adr/ADR-015-*.md`, `docs/tasks/`, `docs/notes/`, `CHANGELOG.md`,
  `README.md`

## Forbidden changes
- `TraktionVision`, `TraktionAI`, `TraktionUI`, FixtureForge, CI, gate
  scripts, `AGENTS.md`.

## Inputs / fixtures
- Shuffled `degraded` control (near-exact overlaps).
- Symmetric two-capture content (shared head and tail bands): both
  directions register uniquely, so the order is unprovable.
- Periodic content: pair-level `ambiguousOverlap` must never become an edge.
- Starved sample budget during graph construction.

## Acceptance criteria
- [ ] Shuffled degraded captures reconstruct in documentary order; output
      rows come verbatim from contributing captures.
- [ ] Symmetric content returns `ambiguousSequenceOrder` with two orders.
- [ ] Periodic content returns `sequenceOrderNotFound`, never a composite.
- [ ] Starved budgets return `resourceLimitExceeded` with no partial choice.
- [ ] `reconstructExactUnordered` and `reconstruct` outputs are unchanged on
      every existing golden (byte equality against the pre-change suite).
- [ ] Evaluation `ordering.correctSequenceRate` reaches 1.0 on the standard
      corpus with 0 false-safe.
- [ ] Complete repository gates pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Required evidence
- command output
- ordering goldens
- evaluation report before/after (`ordering` summary)

## Writer
Unassigned (next engine writer; one writer per branch).

## Reviewer
Independent engine reviewer required before merge (false-safe review per
`AGENTS.md`).
