# Task: Non-destructive seam adjustment and undo

Status: in progress — implementation and portable verification complete; native CI remains required.

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
- [ ] Actual simulator tests cover accessible adjustment controls and undo/redo.
- [ ] Existing core/PNG/native gates, ADR and independent review pass.

One writer owns implementation. Independently review source selection, seam
boundaries, undo history, confidence preservation and resource ownership.

Implementation decision: [ADR-023](../adr/ADR-023-reversible-seam-selection.md).
Verification: [2026-09-17 note](../notes/2026-09-17-seam-editing.md).
