# ADR-014: Unique Acceptable Order for Automatic Order Recovery

Status: Accepted

## Context

Milestone 2 (docs/ROADMAP.md) requires recovering the documentary order of
an unordered capture set. RECONSTRUCTION_SPEC.md §Ordering specifies a
pairwise overlap graph and reserves the typed states `ambiguousOrder` and
`missingCoverage`. ADR-012 already established that a translation is chosen
only when it is the *unique* acceptable one; ordering multiplies the same
risk across the whole set — a plausible-but-wrong order duplicates or drops
documentary rows wholesale.

## Decision

`ReconstructionEngine.recoverOrder` builds a directed graph over the input
captures: edge *i → j* exists exactly when the unchanged Milestone 1
registration pipeline (sampled bounds, ADR-013 early-exit verification,
full verification, ADR-012 uniqueness) accepts a unique overlap in which
*j* continues *i*. On top of that graph, the **unique-acceptable-order
rule**:

- exactly one directed path covering every capture → that order is
  returned, with per-junction evidence;
- more than one → `ambiguousOrder` (a deterministic sample of candidate
  orders plus the exact total);
- none → `missingCoverage` (the deterministic longest acceptable chain and
  the captures it leaves unconnected — a diagnostic, never a selection).

Fail-closed properties:

- A pair-level `ambiguousOverlap` contributes **no** edge; unprovable
  evidence can therefore only remove orders, never create one.
- Any budget exhaustion while probing a pair aborts the whole recovery
  with `resourceLimitExceeded`; no order is chosen from a partial graph.
- Byte-identical captures remain the typed `duplicateCapture` failure.
- `reconstructRecoveringOrder` feeds the recovered order through the
  reviewed supplied-order `reconstruct`, so the final plan and pixels are
  re-verified by the Milestone 1 path (defense in depth at ~2× cost on the
  chosen junctions; with at most 10 captures the graph is at most 90
  individually budgeted probes).

Path counting uses subset dynamic programming (exact; bounded by 10! and
far inside `Int`); enumeration and the longest-chain diagnostic use
deterministic lexicographic index order, so identical inputs produce
identical results and identical failure payloads.

## Consequences

- Reversed and misplaced captures reconstruct without user-supplied order
  (goldens: `Tests/Golden/OrderRecoveryTests.swift`).
- Sets whose order is genuinely unprovable (symmetric content) or whose
  coverage has gaps refuse with typed, actionable failures instead of a
  best guess.
- Edge evidence is registration-only for now; OCR continuation and
  geometry priors (spec §Ordering) are later, additive evidence sources
  and may narrow `ambiguousOrder` cases without changing this rule.
