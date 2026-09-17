# Native reversible seam editing — 2026-09-17

Task: [0020](../tasks/0020-nondestructive-seam-adjustment.md).
Decision: [ADR-023](../adr/ADR-023-reversible-seam-selection.md).

## Behavior

Select a joint in Pixel inspection, then deliberately choose Adjust this seam.
The inspector shows automatic and current seam coordinates separately. One-pixel
and ten-pixel controls preview source selection within the existing proven
overlap; source menus continue to show unchanged original captures. Apply commits
one history step. Cancel discards the draft. Undo/redo restore complete seam
states and original-source pixel selection across multiple joints. Closing the
sheet preserves committed history and discards a draft. Reset or capture
replacement clears history.

The automatic reconstruction remains immutable. Modified state refers to manual
seam coordinates, not a different registration or improved confidence. This step
adds no translation correction, gap bridging, trimming, persistence or export.

## Resource ownership

No edited full-resolution composite is created. Core renders bounded frames from
validated original source strips. Admission adds 32 MiB to retained workspace
rasters and display copies, covering inspection plus a bounded workspace-preview
transition. The existing measured ten-capture case totals 249,824,080 bytes
against the unchanged 268,435,456-byte budget. This is admission arithmetic,
not a new process-memory measurement or physical-device guarantee.

Apply/undo/redo render off-main and publish plan, preview and history together.
Cancellation and generation checks reject stale results even if a worker ignores
cancellation. Replacement work remains blocked until old workers drain.

## Verification record

Linux Swift 6.0.3 release build passes. The focused run passes **32 tests**, with
zero failures, including all **11 new tests** and existing inspection/workspace
regressions. Commands:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest TraktionWorkspaceTests.SeamEditingTests,TraktionWorkspaceTests.NativeSeamEditingModelTests,TraktionWorkspaceTests.NativeInspectionModelTests,TraktionWorkspaceTests.InspectionRasterTests,TraktionWorkspaceTests.NativeWorkspaceModelTests
```

`git diff --check` passes. Independent source review found an undo/redo error that
was hidden in Entire result; the error is now presented beside shared history
controls, with a failed-undo preservation regression. Re-review found no remaining
source-review blockers. Apple compilation and actual simulator execution remain
required; no native result is claimed before those CI gates run.

New portable suites: `SeamEditingTests`, `NativeSeamEditingModelTests`.
New simulator cases
`TRAKTIONLaunchTests.testSeamAdjustmentCancelApplyUndoRedoAndReopen` and
`TRAKTIONLaunchTests.testDraftSeamOriginalSourcesAndOrientation` use the existing
baseline fixture in the Debug lane. They verify the exact one-pixel boundary
change, cancel/apply/undo/redo, both original sources, draft result, landscape
orientation and reopening. The existing large-text inspection case also
exercises reachable adjustment controls. Named screenshots record applied
history, a landscape draft and larger-text adjustment controls. No new fixture bootstrap or
shipping dependency is required.
