# Task: Local project persistence

Status: queued — after task 0020 and the repository-health PR are reviewed.
Writer: assign one implementation owner at start.

## Goal
Save and reopen a reconstruction project offline without losing original captures,
confirmed order, registration evidence or committed seam adjustments.

## Scope
- Define a versioned on-disk project contract and ADR before implementation.
- Preserve original PNG bytes, capture identity/order and validated committed
  metadata; treat previews as disposable derived data.
- Save atomically to an explicit user-selected destination. Failed/cancelled saves
  must not damage an existing project; reopening failure preserves the workspace.
- Validate schema, references, image bounds, resource admission and seam evidence
  before publishing a loaded workspace; reject corrupted/unsupported projects.
- Restore the committed result from original pixels through the shipping core;
  decide and document whether undo history survives reopening.
- Add accessible native save/open status and cancellation without network access.

## Non-goals
Cloud sync, export/share formats, source deletion, gap repair, semantic review,
and physical-device distribution.

## Acceptance criteria
- [ ] Save/open round trip preserves original bytes, order, evidence and edited pixels.
- [ ] Unknown versions, missing/corrupt sources and invalid plans are typed failures.
- [ ] Failed replacement, cancellation and stale completion preserve current work.
- [ ] Large synthetic project admission stays within documented resource limits.
- [ ] Actual native save/open interactions and offline behavior are verified.
- [ ] Core/PNG/native gates, independent review, ADR and user documentation pass.
