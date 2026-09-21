# Task: Local project persistence

Status: implementation verified in PR #21 — stacked on the open repository-health PR.
Final pushed-head checks remain the PR merge gate.
Writer: persistence_implementation; root owns integration, branch `codex/local-project-persistence`.

Contract: [ADR 024](../adr/ADR-024-local-project-container.md).

## Goal
Save and reopen a reconstruction project offline without losing original captures,
confirmed order, registration evidence or committed seam adjustments.

## Scope
- Define a versioned on-disk project contract and ADR before implementation.
- Preserve original PNG bytes, capture identity/order and validated committed
  metadata; treat previews as disposable derived data.
- Save atomically to a new file at an explicit user-selected destination. Existing
  entries are never overwritten; failure/cancellation before publication leaves
  no new file, postcommit status stays truthful, and opening failure preserves
  the workspace.
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
- [x] Existing destinations, cancellation and stale completion preserve current work.
- [x] Large synthetic project admission stays within documented resource limits.
- [x] Actual native save/open interactions and offline behavior are verified.
- [x] Core/PNG/native gates, independent review, ADR and user documentation pass.

## Implementation verification

- Local Swift 6.0.3 release build passed in 19.69 seconds; the complete XCTest
  executable passed **220 Linux cases**, zero failures, in 22.620 seconds.
  Commands and incremental repair history are retained in the
  [continuation log](../notes/2026-09-21-local-projects.md).
- [Run 35569321865](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865)
  at `5821eac039b9e182bc465572e32090aaf40c08e7` passed repository/Linux/Apple:
  **218 Linux / 217 Apple XCTest cases**, PNG smoke, **45/45 evaluations**,
  both isolated performance cases per platform and **eight guard regressions**.
  Linux additionally exercises actual cross-filesystem refusal using `/dev/shm`.
- Independent Core/store/model regressions cover original bytes after source
  deletion, final seams that cannot be replayed sequentially, edited source-pixel
  oracles, forged evidence, malformed framing/JSON/CRC and admission before decode.
- File and lifecycle checks cover no-clobber destination races, private staging
  source-substitution resistance, unrelated-file/symlink preservation, cancellation
  on both sides of publication, truthful cleanup reporting and stale/reset results.
  Real missing-file, staging and known decoder I/O errors remain distinct from
  corrupt content. Nonpositive manifest/source lengths report invalid framing;
  oversized lengths retain resource failures. Exact-cap positive controls preserve
  bytes and pixels. Independent reviews found no remaining blocker.
- Native tests cover actual Files save/open after termination and an empty launch,
  restored order/evidence/committed seam with fresh history, XXXL controls,
  cancellation, corrupt selection and collision refusal preserving both current
  work and the original saved project. Run 35569321865 passed **13 Debug cases**
  in **688.860 seconds** and the **one full-phone Release case** in **70.589 seconds**,
  both inventory guards and the required aggregator, with no retries/timeouts.
  The real local Files path is exercised; the app contains no network/model
  transport. External providers and physical devices remain outside this evidence.
- Reopened state, committed-seam, XXXL controls and corrupt-project screenshots
  were visually inspected; [unchanged captures and provenance](../../assets/screenshots/README.md)
  are retained. The later length-classification follow-up has the local 220-case
  result above; final-head Apple/native results are tracked in
  [PR #21](https://github.com/VASEYDEV/TRAKTION/pull/21).
- Shell syntax, plist/UTI checks and `git diff --check` passed. User documentation
  matches the create-only/private-staging contract; PNG export is queued as
  [task 0023](0023-bounded-png-export.md).
