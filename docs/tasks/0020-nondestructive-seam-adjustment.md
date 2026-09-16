# Task: Non-destructive seam adjustment and undo

Status: queued — next after task 0019.

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
- [ ] Each accepted edit matches an independent original-source pixel oracle.
- [ ] Out-of-overlap/crossing/invalid seams are refused before allocation.
- [ ] Unchanged or cancelled edits retain the original reconstruction exactly.
- [ ] Undo/redo restore exact plans and pixels, including after several joints.
- [ ] Import/reset/cancellation cannot publish an old edited result.
- [ ] Resource and off-main behavior cover phone-size and long synthetic inputs.
- [ ] Actual simulator tests cover accessible adjustment controls and undo/redo.
- [ ] Existing core/PNG/native gates, ADR and independent review pass.

One writer owns implementation. Independently review source selection, seam
boundaries, undo history, confidence preservation and resource ownership.
