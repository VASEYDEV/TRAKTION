# 2026-09-01 — Automatic order recovery (tasks 0008, 0009)

Milestone 2 opener on `claude/traktion-dev-setup-f24qtq`, after the PR #7
merge. The prompt-07 Milestone 1 audit runs concurrently in an independent
session against a pristine clone of merged main (`aaf5e69`); its findings, if
any, land before this branch merges.

## Task 0008 — order recovery engine

`register` refactored into `probePair` (an outcome: accepted / insufficient /
ambiguous; duplicates and budgets still throw) plus a byte-identical throwing
wrapper — one registration implementation for both supplied-order and graph
probing. `recoverOrder` probes all directed pairs (≤ 90, each individually
budgeted), then requires a **unique** directed path covering every capture
(ADR-015, mirroring ADR-012 at order scale): >1 → `ambiguousOrder` with a
deterministic sample + exact count (subset-DP, bounded by 10!); 0 →
`missingCoverage` with the deterministic longest chain; pair ambiguity is
never an edge. `reconstructRecoveringOrder` replays the recovered order
through the reviewed supplied-order path, so final pixels are re-verified.

Adversarial goldens: symmetric two-capture content (shared head+tail bands)
refuses with both orders listed; the periodic-ambiguity content refuses as
`missingCoverage`; a starved sample budget fails closed during graph
construction; byte-identical duplicates stay `duplicateCapture`.

## Task 0009 — tooling

`traktion-lab reconstruct --recover-order`; manifest schemaVersion 3
(`orderRecovered`, `recoveredOrder`, captures in reconstruction order —
failure manifests keep supplied order). Smoke: shuffled recovery composite
byte-identical to the supplied-order composite twice over, and a
missing-middle recovery leaves a `missingCoverage` failure manifest; the
plain-run manifest is pinned to gain nothing but the version bump. The
evaluation corpus adds order-shuffled (5 captures), order-reversed, and
order-missing-middle (19 cases total); a recovered order differing from the
documentary order is classified false-safe even with plausible pixels.

## Verification

`check-repository` PASS · `verify-core` PASS (see PR for count) · `smoke`
PASS (incl. new ordering sections) · `traktion-lab evaluate` 19/19, exit 0.
Apple lane in CI.
