# ADR-016: Fail Closed on Repeated Interface Bands

Status: Accepted

## Context

A capture can contain the same fixed viewport chrome at both its top and
bottom. When the next capture carries the same chrome, the preceding suffix
and following prefix form a short exact overlap even though they do not prove
scroll continuity. The unique-translation rule in ADR-012 can therefore
accept the chrome while rejecting the longer, contaminated documentary
overlap, producing duplicated and missing rows with `exact` confidence.

Pixels alone cannot distinguish fixed chrome from legitimate documentary
content that happens to repeat at the same viewport edge. Accepting either
case would silently corrupt one of them.

## Decision

After supplied-order registration selects one unique acceptable overlap of
`k` rows, and only when `k` is shorter than the preceding capture, the engine
compares the accepted band with the same-position viewport edges. It returns
`repeatedInterfaceArtifact(preceding:following:rows:)` when either:

- the first `k` rows of both captures are byte-identical; or
- the last `k` rows of both captures are byte-identical.

The failure has the stable code `repeatedInterfaceArtifact`. No composite or
joint is produced. The guard uses raw RGBA byte equality and does not mask,
remove, infer, or replace pixels.

The full-height prefix case is excluded because a shorter capture can be a
valid prefix of a following capture that extends the document. Exact
unordered recovery remains governed by its graph uniqueness rule; repeated
chrome creates competing paths and returns `ambiguousSequenceOrder`.

## Consequences

- Identical top-and-bottom chrome and solid repeated edge bands fail visibly
  instead of producing false-safe output.
- Existing baseline, near-exact, repeated-looking-row, scrollbar, overlap,
  adaptive-refinement, and phone-scale positive controls are unchanged.
- A real document with the same byte-identical content band at corresponding
  viewport edges now produces a conservative false warning. A golden pins
  that cost so a later evidence source can lift it deliberately.
- Milestone 4 may identify and mask fixed elements, then represent this state
  as a reviewable joint. That requires a separate decision and does not alter
  this fail-closed Milestone 2 rule.
