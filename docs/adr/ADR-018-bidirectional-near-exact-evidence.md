# ADR-018: Refuse bidirectional near-exact registration evidence

Status: Accepted

## Context

ADR-012 proves uniqueness among overlap lengths in one supplied direction.
That is insufficient when missing coverage and repeated content yield one
plausible forward translation and one plausible reverse translation. Task
0014's original monospaced fixture demonstrates this: a 48-row gap is
accepted as a 57-row near-exact overlap despite a competing 30-row reverse
overlap. Adding a gutter to the synthetic positive fixture did not fix the
engine's acceptance of the original pixels.

## Decision

After the supplied-order path finds a unique near-exact overlap, evaluate the
reverse pair using the unchanged registration thresholds and verification
algorithm. Accept the forward registration only when the reverse probe has
no acceptable placement. Either a unique reverse match or multiple accepted
reverse matches yields `ambiguousOverlapDirection`, recording the forward
overlap and sorted reverse overlaps. The engine throws before making a plan
or rendering a composite.

The two probes share one joint's configured sample and full-comparison
budgets. If the reverse direction cannot be disproved within those budgets,
`resourceLimitExceeded` replaces successful reconstruction. The reverse
probe is the raw scoring operation and never recursively checks direction.

To preserve phone-scale availability within that shared allowance, the reverse
probe first computes UInt64 sums for each RGBA channel in each row of the
searchable preceding suffix and following prefix. For aligned rows,
`sum_channels(abs(sum_pixels(a) - sum_pixels(b)))` is a lower bound on their
full absolute pixel difference by triangle inequality. Dividing the accumulated
bound by the candidate's full pixel count, four channels, and 255 uses the
existing error denominator. A candidate is rejected only when this bound
already exceeds the unchanged threshold. It is never added to overlapping
sample evidence; survivors still receive the original pixel verification.
Both source visits and each RGBA summary comparison consume the joint's sample
budget. Summary storage is proportional to the bounded overlap search, not the
entire height of an arbitrarily taller capture.

The check applies to near-exact matches; existing byte-exact behavior stays
subject to ADR-012 and the fixed-interface guard. Unordered near-exact
recovery retains its global graph rule and replays a unique recovered order
through this supplied-order path. A globally unique graph path can therefore
still refuse if one replayed near-exact pair has reverse evidence; graph
uniqueness does not override this additional pair-level guard. The original two-capture regression is
already ambiguous in the unordered graph and continues to refuse there.

## Consequences and limits

- The preserved task-0014 gap is rejected without altering its source pixels
  or registration thresholds.
- Legitimate repeated content with trusted supplied order can also refuse.
  Supplied order does not itself prove continuity when both translations fit.
- The extra reverse probe uses bounded work and no full-size image copies.
  Near-exact sequences may now reach an existing resource budget earlier.
- This is a bounded ambiguity guard, not proof against all missing coverage.
  A gap with only one plausible direction remains outside this protection;
  stronger documentary anchors or an explicit review workflow are future work.
- Task 0010's related containment bug is fixed by requiring a chrome match
  to be shorter than both captures. A shorter following exact suffix otherwise
  compared its pixels with themselves and was incorrectly refused.

## Evidence

`MonospacedCoverageGapTests` preserves the unanchored source, checks deterministic
typed failure, multiple reverse placements, shared budgets, and unchanged
anchored positives. An exhaustive pixel oracle checks reverse candidates with
nonzero channel-sum differences, and a tall/short pair bounds summary scans.
`ReconstructionGoldenTests` covers exact prefix and suffix containment.
`ReconstructionFailureCodableTests` pins the new failure code; the near-exact
1170×2532 phone test verifies default-budget availability. Full suite and
evaluation results belong in task 0014 after execution.
