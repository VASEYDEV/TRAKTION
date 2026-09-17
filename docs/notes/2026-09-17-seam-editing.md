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

## First integrated simulator run

[Run 35220734815](https://github.com/VASEYDEV/TRAKTION/actions/runs/35220734815)
at `48dc450` passed repository/Linux/Apple checks: 189 core tests on each
platform, both PNG paths and 45/45 evaluations. Both new native editing scenarios
passed (75.045 seconds for draft/source/rotation and 82.979 seconds for
apply/cancel/undo/redo/reopening). The run is still a **failed native gate**:
the expanded XXXL inspection case exceeded XCTest's unchanged two-minute budget,
then emitted a passing case line after 145.946 seconds. The following test failed
to terminate that app process; XCTest restarted and retried it. Xcode's nonzero
exit correctly failed the lane despite those later passing lines.

The XXXL viewport-control flow and joint/seam-control flow are now separate
cases. All original coordinate, visibility, containment, enabled-state, tap and
screenshot assertions remain. Each case starts a fresh baseline import; no input,
assertion, timeout or required gate was weakened. Expected native inventory is
now **nine Debug cases plus one full-phone Release case**. Fresh simulator
verification is required before closing the task.

Independent failure review also found redundant accessibility polling in the
reveal helper: a `for ... where !isHittable` loop still queried all 20 iterations
after the target was visible. It now breaks as soon as the target is hittable,
retaining the same 20-drag bound and final existence/hittability assertions.
This removes repeated snapshots without changing scrolling geometry or coverage.

## Verified implementation closure

[Run 35222997795](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795) at `1daafd6d013eb4af92d26b2c4061b22e8cb1e1e4` passed all five jobs. Linux and Apple each
ran 189 XCTest cases, PNG smoke, 45/45 evaluations and both isolated performance
cases. Native verification passed **nine Debug cases** in 312.551 seconds
and the unchanged **one full-phone Release case** in 61.950 seconds.
Both source-inventory guards passed; there were no failed/retried/timed-out case
records. The focused XXXL scenarios and early-exit reveal helper resolve the
first run's test-structure failure without increasing limits or dropping checks.

Applied-history, landscape-draft and XXXL seam-control attachments from the
successful run were actually inspected. The modified state/history, draft
boundary and accessible controls are visible. An unmodified editor screenshot
is retained in the README gallery with exact provenance.

Tasks 0020/0021 are complete in [PR #20](https://github.com/VASEYDEV/TRAKTION/pull/20),
which remains open as requested. Task 0022 is the next implementation packet.
This records the verified implementation run; current PR checks remain the
merge gate after documentation/artwork changes. Final-head CI is recorded in
the PR rather than creating another documentation-only verification cycle.
