# ADR-014: Exact Evidence Before Automatic Sequence Ordering

Status: Accepted

## Context

Milestone 1 accepts supplied capture order. Milestone 2 introduces automatic
ordering, where a wrong choice can produce a visually plausible but
documentarily false image. Pairwise “best match” selection does not prove a
global order, especially with repeated content.

## Decision

The first automatic-ordering entry point is explicitly exact-only. It creates a
directed edge when a capture suffix and another capture prefix are byte-exact
for at least the configured minimum overlap, enumerates complete paths, and
reconstructs only if exactly one path uses every capture once.

No complete path returns `sequenceOrderNotFound`. More than one complete path
returns `ambiguousSequenceOrder` with the first two deterministic candidate
orders. Nodes are sorted by stable capture identity before traversal, so output
and diagnostics do not depend on input permutation. Pairwise work is charged
against `maximumOrderingComparisonPixels`; exhausting it fails the entire
operation rather than accepting a partially built graph.

The existing supplied-order entry point remains unchanged. Near-exact ordering
requires a later task with a global uniqueness proof and must not be silently
folded into this API.

## Consequences

- Exact shuffled screenshots can be recovered offline without weakening pixel
  authority or registration acceptance rules.
- Gaps, noisy overlaps, and repeated exact boundaries refuse rather than guess.
- Pairwise graph construction is quadratic in capture count but bounded at ten
  captures and by an explicit pixel-comparison budget.
- New typed failures extend the persisted failure wire contract.
