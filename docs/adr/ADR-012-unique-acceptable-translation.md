# ADR-012: Registration Requires a Unique Acceptable Translation

Status: Accepted

## Context

Milestone 1 registration searches vertical overlap lengths and scores each
candidate by full-pixel comparison. Distinct acceptable lengths are distinct
translations; a lower error alone cannot prove which translation is correct — a
short exact repeated band (repeated UI rows, periodic content) can outrank the
true longer near-exact overlap and silently duplicate or drop documentary rows,
violating the no-fabrication invariant.

## Decision

A joint succeeds only when **exactly one** fully verified overlap length meets
the acceptance thresholds. Any second acceptable candidate returns
`ambiguousOverlap` and produces no composite. Budgets are fail-closed the same
way: if every still-plausible candidate cannot be fully verified within the
configured budget, the result is `resourceLimitExceeded`, never a choice from a
partial ranking.

This policy was introduced in PR #4 (including the corresponding change to
`docs/RECONSTRUCTION_SPEC.md` §3), validated by the independent engine review
of head `dd2dd76`, and ratified by the owner at merge. This ADR records that
ratification, closing the review's process findings.

## Consequences

- False-safe stitches are structurally hard: an exact true overlap is always
  acceptable, so a competing wrong candidate triggers ambiguity instead of
  winning. Adversarial probes (blank documents, sub-minimum true overlap,
  repeated bands) end in typed failures, not corrupted composites.
- Availability is the cost: repetitive or low-texture captures can refuse to
  reconstruct (`ambiguousOverlap`/`resourceLimitExceeded`) at default budgets.
  Raising recall (adaptive verification, anchor features, OCR continuity)
  belongs to later milestones and must not weaken the uniqueness rule.
