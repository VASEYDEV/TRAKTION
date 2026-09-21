# Task: Local project persistence

Status: implementation ready for Apple/native CI — stacked on the open repository-health PR.
Writer: persistence_implementation, branch `codex/local-project-persistence`.

Contract: [ADR 024](../adr/ADR-024-local-project-container.md).

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
- [x] Save/open round trip preserves original bytes, order, evidence and edited pixels.
- [x] Unknown versions, missing/corrupt sources and invalid plans are typed failures.
- [x] Failed replacement, cancellation and stale completion preserve current work.
- [x] Large synthetic project admission stays within documented resource limits.
- [ ] Actual native save/open interactions and offline behavior are verified.
- [ ] Core/PNG/native gates, independent review, ADR and user documentation pass.

## Implementation verification

- Swift 6.0.3 Linux release build including test discovery passed.
- Full portable suite: 204 XCTest cases, zero failures, 21.681 seconds.
- After exclusive temporary-file creation was added, the release build and all
  11 project-store cases passed again (0.121 seconds).
- Six repository result-inventory tests, shell syntax, plist parsing/UTI contract
  and `git diff --check` passed.
- Direct restore, exact original bytes after source deletion, independent edited
  pixel oracle, evidence tampering, malformed framing/CRC, aggregate admission
  before decode, atomic failure/cancellation, no-clobber race, symlink refusal,
  cleanup reporting and model stale/reset/commit cases are covered.
- Native tests are authored for real Files save/open after termination and empty
  launch, XXXL controls/open cancellation, save-name/folder cancellation and
  corrupt-project selection with preserved reconstruction. Apple build, real
  picker behavior and current-commit CI must still pass before closure.
