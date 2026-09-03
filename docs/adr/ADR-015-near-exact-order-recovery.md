# ADR-015: Near-Exact Order Recovery Under a Global Uniqueness Rule

Status: Accepted

## Context

ADR-014 made the first automatic-ordering entry point exact-only and
reserved near-exact ordering for "a later task with a global uniqueness
proof". Any lossy capture pipeline (the `degraded` control, screenshots
re-encoded by messaging apps) leaves no byte-exact suffix/prefix edge, so
`reconstructExactUnordered` refuses inputs whose every pair nevertheless
registers uniquely under the Milestone 1 thresholds. ADR-012 already
established that a translation is chosen only when it is the *unique*
acceptable one; ordering multiplies the same risk across the whole set — a
plausible-but-wrong order duplicates or drops documentary rows wholesale.

## Decision

`ReconstructionEngine.reconstructNearExactUnordered` builds a directed graph
over the captures in stable capture-identity order: edge *i → j* exists
exactly when the unchanged Milestone 1 registration pipeline (sampled
bounds, ADR-013 early-exit verification, full scoring, ADR-012 uniqueness)
accepts a unique overlap in which *j* continues *i*. On that graph the same
rule as ADR-014 applies: exactly one path using every capture once
reconstructs; none returns `sequenceOrderNotFound`; more than one returns
`ambiguousSequenceOrder` with the first two deterministic candidate orders.
No new failure codes are introduced.

Registration is refactored into an outcome-returning `probePair` plus a
throwing `register` wrapper that maps the outcomes back to the identical
typed failures at the identical decision points, so supplied-order behavior
is byte-identical and one registration implementation serves both paths.

Fail-closed properties:

- A pair-level `ambiguousOverlap` contributes **no** edge; unprovable
  evidence can only remove orders, never create one.
- Duplicate captures, the per-joint sample and full-comparison budgets, and
  the conservative whole-recovery bound (`maximumOrderingComparisonPixels`,
  charged with the full potential overlap area of every ordered pair before
  any probe, exactly as the exact path does) all throw
  `resourceLimitExceeded` or `duplicateCapture`; a thrown probe discards the
  graph, so no order is ever chosen from a partial search.
- The recovered order is replayed through supplied-order `reconstruct`, so
  the final plan and pixels are produced and re-verified by the reviewed
  Milestone 1 path.
- Path enumeration is a depth-first search in node order that stops at the
  second complete path; with at most ten captures this is an exact decision
  for "zero, one, or more than one" and reuses the exact path's traversal.

## Consequences

- Near-exact shuffled and reversed captures reconstruct offline without
  weakening pixel authority or registration acceptance rules; joints stay
  `strong` and output rows come verbatim from contributing captures
  (goldens: `Tests/Golden/NearExactOrderingTests.swift`).
- Symmetric content and coverage gaps refuse with the existing typed
  failures; periodic content whose pairs are ambiguous refuses as
  `sequenceOrderNotFound` because its ambiguous pairs never become edges.
- A gap and sub-threshold noise remain indistinguishable in
  `sequenceOrderNotFound`; diagnosing which is a later evidence source
  (OCR continuation, geometry priors), additive to this rule.
- The identical top-and-bottom chrome false-safe (task 0010) is unchanged
  by this path: every such pair carries an accepted band edge in both
  directions, so recovery refuses as ambiguous rather than composing.
- Graph construction costs up to 90 individually budgeted probes; the
  whole-recovery bound is conservative (work examined, not work done).
