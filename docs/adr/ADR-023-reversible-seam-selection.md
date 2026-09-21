# ADR-023: Reversible seam selection from original pixels

Status: Accepted; native acceptance remains a merge gate for task 0020.

## Context

The native workspace retains original captures and the automatic reconstruction.
The measured ten-capture workspace owns 216,269,648 bytes before inspection. A
second 89,013,600-byte full-resolution composite would exceed its 256 MiB raster
budget. Undo cannot retain bitmap copies. Manual selection must not alter proven
registration, documentary content, source files or confidence.

## Decision

Keep `ReconstructionResult` immutable and internally consistent. A separate
`SeamEditingDocument` retains the automatic plan, committed plan and metadata-only
undo/redo snapshots. Drafts are separate values keyed by both original capture
IDs. Only seam offsets and their derived output boundaries may change. All
placements, image dimensions, overlap lengths, confidence and measured evidence
remain unchanged. Returning every seam to its automatic position clears Modified
status even if history exists.

`TraktionCore` validates capture identity, dimensions, placement arithmetic,
adjacency, overlap, evidence and source coverage before any raster allocation.
Only existing Exact/Strong overlaps qualify. Seams may reach either proven
overlap boundary but must remain strictly between neighboring seams, preserving
at least one row from each capture. A zero-length capture strip is refused;
cutting content is outside this task. The following capture owns the boundary
row. Every output pixel is copied directly from one original at
`outputRow - placement.originY`; no blending, synthesis or registration rerun.

The validated `PlannedRasterRenderer` resolves source strips once per sampled
output row. It renders at most 1,048,576 RGBA pixels with an edge at most 4,096;
inspection further restricts its viewport to 1,024 × 1,024. Neither history nor
preview requests allocate a full edited composite. Standard raster inspection
continues to use the unchanged automatic raster until an edit changes the plan.

A workspace-owned editing model survives sheet dismissal. Draft preview changes
only the inspected composition. Apply/undo/redo publish a new committed plan and
bounded workspace preview together after successful off-main rendering. Failed
or cancelled work leaves the committed plan, preview and history intact. A new
apply after undo clears redo. Closing inspection cancels its draft. Reset,
successful replacement, reordering or capture removal clear the session.

A serial preview worker and the existing coalescing inspection worker use
independent cancellation/generation tokens. Stale completions cannot publish;
workspace admission remains busy until draining jobs actually finish. Additional
editing admission reserves 32 MiB: the existing 24 MiB viewport allowance plus
8 MiB for incoming bounded preview and display storage while the prior preview
is retained. The measured ten-capture case totals 249,824,080 bytes. A workspace
that fits read-only inspection but not editing explicitly keeps editing disabled.
This is an owned-raster policy, not a hard process RSS, framework-cache, GPU or
physical-device memory guarantee. No raster budget or reconstruction threshold
is increased.

## Verification

Source-marked original rasters expose ownership mistakes that exact-overlap
fixtures cannot detect. Independent oracles specify the expected source for every
pixel, including overlap endpoints and several edited joints. A real near-exact
engine fixture proves that manual selection can change output pixels while
preserving registration evidence. Tests cover rejection before allocation,
nondivisible preview sampling, no-op/cancel, history branching, cancellation-
ignoring workers, reset/replacement, admission and 1170 × 19020 lazy rendering.
Native UI tests cover deliberate adjustment, cancel/apply, undo/redo, reopening,
reset and accessible larger-text controls. Native CI results are recorded in the
task note before completion is claimed.
