# UI tests

`TRAKTIONLaunchTests.swift` belongs to the Xcode `TRAKTIONUITests` target, not
the SwiftPM test suite. The shared `TRAKTION` scheme launches the native iOS
app and exercises real PNG import through the production service, explicit
order confirmation, move/remove, reconstruction, duplicate and missing-coverage
failures, reset, portrait/landscape, and larger text. A separate test presents
the real Files picker and verifies cancellation preserves the workspace.

Run `bash scripts/verify-ios.sh` on macOS with Xcode and an installed iOS
simulator runtime. The script generates deterministic PNGs with FixtureForge
and copies capture files into the dedicated simulator app's private Library/Application Support directory.
A Debug/test-build bootstrap reads the named scenario from `TRAKTION_UI_FIXTURE` and
passes those URLs to the production importer. It never confirms order or runs
reconstruction automatically, and FixtureForge is not linked into the app.

Source truth, fixture manifests, generated PNGs, Xcode logs, screenshots, and
results remain in the run's artifact directory. See
`docs/runbooks/ios-development.md` for signing and diagnostic output. Pixel
identity and source hashes are also tested below the UI boundary. These tests
do not claim third-party Files-provider compatibility, physical-device signing
or export coverage. Seam editing and local project scenarios are described below;
their execution evidence belongs to the current PR's native CI run.

Task 0019 adds pixel/joint inspection on a genuine 1170 × 6196 composite, covering
1:1, both-axis pan, bottom navigation, stable joint/source selection, exact seam
metadata, orientation, dismiss/reopen/reset, and XXXL controls. Four additional
named screenshots are attached. The ten-capture 19,020-row raster and resource
checks run separately in the portable tests/probe. See ADR-022 for pixel-scale
semantics and the distinction between owned raster reservation and device RSS.

`verify-ios.sh` runs the small-input cases against Debug and the unchanged
full-size inspection case against a separately built Release app. No test is
omitted overall. `TRAKTION_UI_TESTING` is set only for that optimized simulator
test build; regular Release builds cannot import fixtures from launch environment.

Task 0020 covers seam draft/apply/cancel, undo/redo, original/current coordinates,
inspector reopening, orientation and XXXL seam controls. With task 0022, the source
inventory contains thirteen Debug cases and one full-phone Release case. Both phase
logs must contain every selected case exactly once with a passing result and no
timeout/restart markers, even if a later record reports a pass.

Task 0022 adds a real Files project round trip: reconstruct and commit a seam,
name a project, confirm the local folder in the system picker, terminate the app,
clear fixture launch input, reopen the saved `.traktion` through Files, and verify
original names/order/evidence and the committed seam with empty undo history.
A separate accessibility-size test checks project controls and picker cancellation.
Another focused case cancels the save-name and Files-folder dialogs, then opens
a deliberately corrupt `.traktion` document through Files and checks that the
existing reconstruction remains unchanged. Only the verification script seeds
that synthetic corrupt document in Documents.
A collision case saves three captures, changes the current reconstruction to two,
refuses the same filename without changing that workspace, then cold-reopens the
unchanged three-capture project.
Picker lookup/dismissal failures record screenshots and the actual accessibility
tree for diagnosis. Successful scenarios retain their final evidence screenshots;
redundant dialog captures are avoided to keep diagnostic overhead within the
unchanged case limits. No project URL, persistence result or saved workspace is
injected into the app.

Documents is exposed to Files for user-selected local projects. Test captures live
in private `Library/Application Support/UIFixtures`, and import/open staging stays
in private temporary storage. The generated Info.plist exports the project UTI and
sets `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. No external
Files tap-to-launch document-handler association is registered in this task.
