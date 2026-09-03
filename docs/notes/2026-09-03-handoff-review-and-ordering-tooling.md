# 2026-09-03 — Handoff review, PR #8 reconciliation, exact-ordering tooling (task 0008)

Writer session on `claude/repo-status-handoff-hfsjyv`, taking over from the
Codex session that merged PR #9 (`c061c92`).

## 1. State of the repository at handoff

- `main` = `c061c92`: Milestone 1 audited (task 0006, pass with follow-ups)
  and fail-closed exact sequence ordering (task 0007, ADR-014) merged from
  Codex's PR #9. Nothing on this branch differed from `main` at start.
- Reproduced the merged gates on Linux with the swift.org 6.0.3 toolchain
  (the container ships none): `check-repository` PASS, `verify-core` PASS
  (73 tests), `smoke` PASS, `traktion-lab evaluate` 16/16.
- **PR #8 is still open** (`claude/traktion-dev-setup-f24qtq`, draft, three
  commits on the pre-audit `main`). It implements *near-exact* order recovery
  (`probePair` refactor, subset-DP path count, `ambiguousOrder` /
  `missingCoverage`, `reconstructRecoveringOrder`), Lab `--recover-order`,
  smoke, and three evaluation cases — under packets numbered 0006/0007 and
  an ADR-014 that all collide with the merged Codex packets and ADR.

## 2. Reconciliation decision

Merged numbers win (`docs/tasks/README.md`, numbering rule). PR #8 must not
be merged as-is: it would reintroduce a second ordering API and a second
ADR-014, and its `missingCoverage` name claims more than exact evidence can
prove (a missing path is either a gap or sub-threshold noise). Its two halves
are re-tracked:

- tooling half → **task 0008** (this branch), ported against the merged
  exact-only API with a value-taking `--order` option so near-exact can be
  added as a third policy without another flag;
- engine half → **task 0009** (planned), a port that keeps the merged
  failure codes, adds the probe refactor and the exact path count, and ships
  ADR-015.

Recommendation to the owner: close PR #8 as superseded once this branch
merges; nothing in it is lost.

Both agents' engine work was read end to end. The Codex exact-ordering
implementation is sound for its contract (stable node order, conservative
pixel budget charged before probing, two-path early stop). Two details worth
knowing: the ordering budget is charged the full potential overlap area of
every ordered pair *before* probing, so it is a bound on work examined rather
than work done (conservative, correct), and `sequenceOrderNotFound` is
returned for any absence of an exact path — gap and noise are
indistinguishable by design until task 0009.

## 3. False-safe finding (task 0010)

While reviewing the sticky-header/footer controls I probed the one shape the
control set does not cover: the **same** band at the top and bottom of every
capture. Supplied-order reconstruction accepts the band as the unique exact
overlap (`[12, 12]` where the truth is `[24, 24]`), marks both joints
`exact`, and emits a composite with 22 missing and 46 duplicated documentary
rows. A solid 8-row band does the same; 12- and 16-row solid bands refuse
only because uniform rows create several exact placements. Exact ordering
on the same captures correctly refuses with `ambiguousSequenceOrder`.

This violates the source-integrity invariant (a low-confidence result
reported as success). The full reproduction, a deterministic guard design,
and its known false-warning cost are in `docs/tasks/0010-repeated-chrome-guard.md`.
It is an engine change with a fixture and an ADR, so it is tracked rather
than folded into the tooling PR; it should be the next engine task before
task 0009 widens the accepted-edge set.

## 4. Task 0008 — what landed

- `traktion-lab reconstruct --order supplied|exact`; manifests schemaVersion 3
  (`orderPolicy`, `recoveredOrder`, captures in reconstruction order so joint
  diagnostics pair true neighbors; failure manifests keep supplied order).
- Smoke: shuffled `--order exact` composite byte-identical to the
  supplied-order composite twice (manifest too); coverage gap →
  `sequenceOrderNotFound` failure manifest, no composite, no diagnostics;
  plain manifest pinned; unknown policy → usage error, nothing written.
- Evaluation: `OrderingCase` (permutation + expectation) on `EvaluationCase`;
  five ordering cases (shuffled 5-capture, reversed control, missing-middle,
  duplicate, degraded-exact-only); report schemaVersion 2 with per-case
  `orderPolicy`/`recoveredOrder` and an `ordering` summary implementing the
  EVALUATION.md metrics. Sequence cases count capability: the pinned
  exact-only refusal on the degraded control is a `pass` by contract and a
  miss in `correctSequenceRate` (2/3) — the number task 0009 must raise.
- Verdict rule: recovered order ≠ documentary order ⇒ false-safe, even with
  plausible pixels. Registration expectations for ordering cases come from
  ground-truth origins in documentary order (`documentOrderOverlaps`), since
  the supplied-order `expectedOverlaps` pin is empty for reversed/gap
  variants.

## 5. Documentation

Task index with the numbering rule; packets 0008–0013; roadmap status
table; `CLAUDE.md` facts for task tracking, toolchain, and handoff; README
status/quick start; runbook evaluation section; this note. `AGENTS.md`
unchanged.

## 6. Verification (Linux, Swift 6.0.3, this branch)

`check-repository` PASS · `verify-core` PASS (77 tests executed, 0 failures;
`main` runs 73 — the audit's "67" predates the six task-0007 goldens) ·
`smoke` PASS including the three ordering sections · `traktion-lab evaluate`
21/21, 0 false-safe, 0 false-warning, 0 wrong-failure, 0 nondeterministic,
ordering 2/3 · 1/1 · 1/1, exit 0 · `git diff --check` clean. Apple lane in
CI.
