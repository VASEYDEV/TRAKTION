# 2026-09-01 — Evaluation harness + adaptive verification (tasks 0004, 0005)

Phase-B completion on `claude/traktion-dev-setup-f24qtq`, on top of the merged
task-0002/0003 corpus work.

## Task 0004 — evaluation harness

`TraktionLabEvaluation` (library beside the Lab CLI) + `traktion-lab evaluate`.
Standard corpus: 16 cases (10 control-set variants, 5 overlap-sweep points,
horizontal). Per case: verdict (pass / false-safe / false-warning /
wrong-failure), pixel equality and row accounting for exact fixtures,
registration error and seam energy per joint, two-run determinism, timing.
The command is a gate (non-zero exit on any unacceptable summary); the Linux
CI lane runs it and uploads `evaluation-report.json`. Current corpus:
16/16 pass, 0 false-safe, all deterministic.

## Task 0005 — adaptive verification (the design detour, recorded honestly)

First attempt was density-scaling refinement rounds (re-sample survivors at
4×/16× density). The arithmetic kills it: pruning a candidate of area A
against a full-denominator lower bound needs ~threshold×A sampled difference,
so fixed-density rounds pay near-full-verification cost blindly — the
prototype passed the 400×800 trap but blew the sample budget at phone scale.

Shipped design (ADR-013): early-exit exhaustive scan of each survivor — full
width, rows in descending edge-energy order of the following capture, running
sums as always-true lower bounds, exit at first threshold crossing. Wrong
candidates on realistic content exit after a few percent of their area; a
completed scan is the exact score, so the true placement is never pruned.
`refinementRounds: 1` = original algorithm byte for byte. Budgets recalibrated
from measurement (~100M comparisons for a 1170×2532 pair → 128M sample budget).

Measured (debug, Linux): 1170×2532 pair reconstructs exactly in ~63 s
(release is expected an order of magnitude faster); the 400×800 trap case
went from `resourceLimitExceeded` (single-pass) to exact reconstruction in
~3 s, and fail-closed behavior on blank/periodic content is unchanged.

## Verification

`check-repository` PASS · `verify-core` PASS (67 tests, 0 failures) ·
`smoke` PASS · `traktion-lab evaluate` 16/16, exit 0. Apple lane in CI.
