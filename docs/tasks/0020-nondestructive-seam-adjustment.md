# Task: Non-destructive seam adjustment and undo

Status: done — verified in [PR #20](https://github.com/VASEYDEV/TRAKTION/pull/20); PR remains open for review/merge.

## Goal
Allow deliberate seam selection inside an already proven overlap, with a visible
original-pixel comparison and reversible history. This is the first editing step.

## Scope
- Define a deterministic edit value and renderer that retain the original plan,
  original captures, registration evidence and confidence.
- Permit moving a seam only within its existing proven overlap, respecting
  adjacent joints and source bounds; refuse unsupported edits explicitly.
- Add an intentional adjustment mode to the joint inspector, with preview,
  apply/cancel and undo/redo. Read-only inspection remains the initial mode.
- Re-render from original pixels off-main with bounded admission, cancellation
  and stale-result protection. Never overwrite imported files.
- Reset/replacement clear edit history; show modified versus original state.

## Non-goals
Translation correction, gap bridging, automatic ordering, trim/cut, project
persistence, export, semantic review and production signing/distribution.

## Acceptance criteria
- [x] Each accepted edit matches an independent original-source pixel oracle.
- [x] Out-of-overlap/crossing/invalid seams are refused before allocation.
- [x] Unchanged or cancelled edits retain the original reconstruction exactly.
- [x] Undo/redo restore exact plans and pixels, including after several joints.
- [x] Import/reset/cancellation cannot publish an old edited result.
- [x] Resource and off-main behavior cover phone-size and long synthetic inputs.
- [x] Actual simulator tests cover accessible adjustment controls and undo/redo.
- [x] Existing core/PNG/native gates, ADR and independent review pass.

One writer owns implementation. Independently review source selection, seam
boundaries, undo history, confidence preservation and resource ownership.

Implementation decision: [ADR-023](../adr/ADR-023-reversible-seam-selection.md).
Verification: [2026-09-17 note](../notes/2026-09-17-seam-editing.md).

Full implementation verification: [run 35222997795](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795) at `1daafd6d013eb4af92d26b2c4061b22e8cb1e1e4`; all five jobs passed. The current PR checks remain required after documentation updates.
