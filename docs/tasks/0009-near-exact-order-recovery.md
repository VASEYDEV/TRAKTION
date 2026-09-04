# Task: Near-exact order recovery on the exact-ordering contract

Status: implemented (this packet's acceptance boxes are ticked from command
evidence). Prior art: PR #8 (`claude/traktion-dev-setup-f24qtq`, commits
`4248c00`/`ce43247`) implemented this design against the pre-audit `main`;
it was closed as superseded and its engine half is ported here onto the
merged task-0007 contract (see
`docs/notes/2026-09-03-handoff-review-and-ordering-tooling.md`, §7).

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
2. A near-exact ordering entry point, `reconstructNearExactUnordered`
   (a sibling of `reconstructExactUnordered`, which stays byte-identical),
   that probes every directed pair with the unchanged registration pipeline
   (ADR-012 uniqueness, ADR-013 early exit, per-joint budgets), creates an
   edge only for `accepted`, and requires exactly one directed path
   covering every capture.
3. Global uniqueness: enumerate complete paths in stable capture-identity
   order with a two-path early stop (an exact zero/one/many decision for at
   most ten captures, reusing the exact path's traversal); more than one
   path returns `ambiguousSequenceOrder` with the first two orders; none
   returns `sequenceOrderNotFound`. Existing failure codes and payload
   shapes are reused unchanged — no `ambiguousOrder`/`missingCoverage`
   twins. Longest-chain diagnostics, if wanted later, go in a
   result/manifest field, not in the failure payload.
4. Bound total probe work: per-pair budgets as today plus a whole-recovery
   accounting (n ≤ 10 → at most 90 probes) that fails the entire recovery
   with `resourceLimitExceeded` before selecting from a partial graph.
5. Replay the recovered order through supplied-order `reconstruct` so final
   plan and pixels are produced and re-verified by the Milestone 1 path.
6. Determinism: identical inputs yield identical orders and failure
   payloads for any input permutation.
7. Tooling: `traktion-lab reconstruct --order near-exact`; the evaluation
   corpus replaces `order-degraded-exact-only` with near-exact cases
   (degraded shuffled → reconstruct, exact shuffled → reconstruct,
   missing-middle → `sequenceOrderNotFound`); smoke generates the degraded
   control and proves `exact` refuses it while `near-exact` reproduces the
   supplied-order composite byte for byte. The symmetric-content ambiguity
   corpus case waits for the task 0010 fixture (the golden covers it).
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
- [x] Shuffled degraded captures reconstruct in documentary order; output
      rows come verbatim from contributing captures; plan and pixels equal
      the supplied-order reconstruction of the same order.
- [x] Symmetric content returns `ambiguousSequenceOrder` with two orders.
- [x] Periodic content returns `sequenceOrderNotFound`, never a composite.
- [x] Starved per-joint and whole-recovery budgets return
      `resourceLimitExceeded` with no partial choice.
- [x] `reconstructExactUnordered` and `reconstruct` outputs are unchanged on
      every existing golden (the whole pre-change suite passes unchanged).
- [x] Evaluation `ordering.correctSequenceRate` reaches 1.0 on the standard
      corpus with 0 false-safe.
- [x] Complete repository gates pass deterministically; no unrelated diff.

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
Claude (branch `claude/repo-status-handoff-hfsjyv`), porting the PR #8
design by the archived "TRAKTION development setup" session.

## Reviewer
Independent engine reviewer required before merge (false-safe review per
`AGENTS.md`).
