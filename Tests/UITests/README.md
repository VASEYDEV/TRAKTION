# UI tests

`TRAKTIONLaunchTests.swift` belongs to the Xcode `TRAKTIONUITests` target, not
the SwiftPM test suite. The shared `TRAKTION` scheme launches the native iOS
app and exercises real PNG import through the production service, explicit
order confirmation, move/remove, reconstruction, duplicate and missing-coverage
failures, reset, portrait/landscape, and larger text. A separate test presents
the real Files picker and verifies cancellation preserves the workspace.

Run `bash scripts/verify-ios.sh` on macOS with Xcode and an installed iOS
simulator runtime. The script generates deterministic PNGs with FixtureForge
and copies capture files into the dedicated simulator app's Documents directory.
A Debug-only bootstrap reads the named scenario from `TRAKTION_UI_FIXTURE` and
passes those URLs to the production importer. It never confirms order or runs
reconstruction automatically, and FixtureForge is not linked into the app.

Source truth, fixture manifests, generated PNGs, Xcode logs, screenshots, and
results remain in the run's artifact directory. See
`docs/runbooks/ios-development.md` for signing and diagnostic output. Pixel
identity and source hashes are also tested below the UI boundary. These tests
do not claim third-party Files-provider selection, physical-device signing,
editing, persistence, or export coverage.

Task 0019 adds pixel/joint inspection on a genuine 1170 × 6196 composite, covering
1:1, both-axis pan, bottom navigation, stable joint/source selection, exact seam
metadata, orientation, dismiss/reopen/reset, and XXXL controls. Four additional
named screenshots are attached. The ten-capture 19,020-row raster and resource
checks run separately in the portable tests/probe. See ADR-022 for pixel-scale
semantics and the distinction between owned raster reservation and device RSS.
