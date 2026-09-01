# ADR-013: Adaptive Early-Exit Candidate Verification

Status: Accepted

## Context

Registration (ADR-012) must prove every overlap candidate but one unacceptable.
The foundation's single sparse sampling pass produces lower bounds against the
full-comparison denominator; at phone scale those bounds are too weak to prune
anything — pruning a candidate of area `A` requires a sampled difference of at
least `threshold × A`, so fixed-density sampling can never reject large
candidates, and the engine failed closed (`resourceLimitExceeded`) on ordinary
large captures (limitation documented in PR #4, tracked as task 0005).

Density-scaling refinement rounds were prototyped and rejected: the same
arithmetic shows they need ~`threshold`-fraction coverage of each candidate's
full area anyway, but pay it blindly across every round.

## Decision

When the sparse first pass leaves more survivors than `candidateLimit`, each
survivor is verified by an **early-exit exhaustive scan**: rows are visited in
descending edge-energy order of the following capture (misalignment is provable
exactly where content changes), at full width, accumulating the absolute
difference and changed-pixel count. Both running values are true lower bounds
at every step, so:

- the scan stops the moment a bound provably exceeds an acceptance threshold —
  a wrong candidate on realistic content is pruned after a few percent of its
  area;
- a scan that completes yields the candidate's exact score — the true
  placement can never be pruned;
- every scanned row is charged against `maximumSampleComparisonsPerJoint`, so
  content that cannot be discriminated (blank or periodic regions) still fails
  closed exactly as before.

`ReconstructionSettings.refinementRounds` gates the pass: `1` reproduces the
original single-pass algorithm byte for byte; `≥ 2` enables the scan. The
unique-acceptable-translation rule, the full verification of final survivors,
and all fail-closed budget semantics are unchanged. Default budgets are
calibrated to measured phone-scale cost (~100M comparisons for a 1170×2532
pair): sample budget 128M, full-comparison budget 64M.

## Consequences

- Phone-scale and large sparse captures reconstruct within default budgets
  (goldens: `Tests/Golden/AdaptiveRefinementTests.swift`,
  `Tests/Performance/PhoneScaleReconstructionTests.swift`).
- Worst-case cost on undiscriminable content is unchanged (budget-bounded,
  typed failure); genuinely ambiguous content still returns
  `ambiguousOverlap`.
- The edge-energy row ordering is deterministic (ties by ascending index);
  identical inputs produce identical plans and pixels.
