# Native iOS development

The Xcode target imports 2–10 opaque equal-width PNG captures from Files,
requires explicit top-to-bottom order confirmation, and shows local supplied-order
reconstruction or a typed failure. Inspection/editing, persistence, and export
are subsequent tasks. No production icon or physical-device release is claimed.

## Open and run
1. Use macOS with Xcode 16 or newer and an installed iOS 17+ simulator runtime.
   Xcode Settings > Components manages runtimes. The repository requires
   Swift 6; the selected Xcode must provide that toolchain.
2. Open `App/TRAKTION.xcodeproj` and choose the shared `TRAKTION` scheme.
   Its native app target is named `TRAKTIONiOS` to distinguish it from the
   SwiftPM preview executable; the installed application remains TRAKTION.
3. Select an iPhone simulator and run. The project resolves `Package.swift`
   from the repository root by a relative local path; no package download or
   project-generation step is required.

The SwiftPM `swift run TRAKTION` executable remains a macOS preview path.
It does not build the iOS application target.

## Reproduce CI
From the repository root:

```sh
bash scripts/verify-ios.sh
```

The script uses the active `xcode-select`/`DEVELOPER_DIR` toolchain. To use a
particular installed Xcode, set `DEVELOPER_DIR` for that invocation. It records
`xcodebuild -version` and simulator availability, selects a compatible
iPhone/runtime pair, and creates a dedicated temporary simulator. It never
erases or installs into an existing personal simulator.

The verification sequence is:
1. Validate/list the checked-in project.
2. Boot the dedicated simulator.
3. Run `xcodebuild build-for-testing` with the shared scheme and
   `CODE_SIGNING_ALLOWED=NO` for this simulator invocation.
4. Generate baseline/duplicate/missing-middle PNG fixtures in a separate
   release CLI process, install the app, and copy only capture PNGs into the
   dedicated simulator app container. Source truth/manifests stay outside it.
5. Launch and run six Debug XCTest scenarios for real import, supplied order,
   reconstruction/refusals, reset, rotation, larger text (including inspection)
   and actual Files picker cancellation.
6. Build/install a Release test app and run the same full-size phone inspection
   scenario with production optimization. The `TRAKTION_UI_FIXTURE` bootstrap
   is available in Debug or with the explicit `TRAKTION_UI_TESTING` test flag;
   it calls the production importer without confirming order or injecting results.
7. Export retained screenshot attachments and shut down/delete the dedicated
   simulator, preserving both test results.

Results live in a new run directory beneath `.traktion-local/ios-smoke`.
Set `TRAKTION_IOS_ARTIFACTS` to change that parent directory. Runs do not
overwrite each other's diagnostics. `TRAKTION.xcresult` contains XCTest
results; `build.log`, `launch.log`, `tests.log`, and toolchain/device JSON
support diagnosis. CI uploads those files as `traktion-ios-verification`.
Screenshots are attached to `TRAKTION.xcresult`; test assertion success and
actual human/agent visual inspection must be reported separately. These tests
do not automate third-party Files provider selection or physical-device use.
Build products remain under the run's `DerivedData` directory and are not
uploaded. Missing prerequisites, build failures, launch failures, and failed
UI assertions make the lane and required aggregator fail.

On Linux, `bash -n scripts/verify-ios.sh` checks shell syntax and
`bash scripts/check-repository.sh` checks repository policy. Neither runs
Xcode, compiles SwiftUI, or establishes that the app boots.

## Physical-device signing
Simulator CI needs no Apple account or team. A physical device does.

`App/TRAKTION/Config/Build.xcconfig` leaves `DEVELOPMENT_TEAM` empty and uses
the development bundle ID `dev.vasey.traktion`. That identifier is not a claim
that an App ID or App Store record has been registered. The project uses
automatic signing for device builds.

Create the ignored file
`App/TRAKTION/Config/Signing.local.xcconfig` and set `DEVELOPMENT_TEAM` to
your actual Apple Developer team ID. If your team needs a different registered
identifier, set `TRAKTION_BUNDLE_IDENTIFIER` in that same file. Xcode also
accepts these as command-line build settings. UI test bundle identifiers are
derived from the app identifier so they remain distinct.

Choose the intended team in Xcode, connect your device, and use its normal
signing flow. Do not add account credentials, private keys, certificates,
provisioning profiles, or the local signing file to git. The simulator script
does not register App IDs, manage certificates, accept agreements, or enable
automatic provisioning updates. Device installation must be verified with
the selected team's actual credentials and device.

Production artwork, physical-device checks, distribution provisioning, App
Store metadata, and release signing are still required before distribution.

## Pixel and joint inspection

After successful reconstruction, select **Inspect pixels and joints**. Fit shows
an overview; **1:1 pixels** maps one source pixel to one physical display pixel.
Drag the image to pan on release, or use direction and top/bottom buttons. The
zoom percentage and zero-based origin describe the current source viewport.
Select a joint to see both filenames/IDs, confidence, overlap and seam boundaries;
choose Result, First original or Second original to inspect their unchanged
pixels. Done clears the inspection session; reopening begins at the result.

The inspection gate adds a 1170 × 6196 three-capture PNG fixture and tests 1:1,
pan, joint/source selection, portrait/landscape, reopening/reset and larger text.
The 1170 × 19020 ten-capture Linux probe measures the same bounded raster renderer
while retaining the full workspace; it is not a device memory claim. Commands
and scoped evidence: [inspection note](../notes/2026-09-16-native-inspection.md).

Native verification runs six small-input UI cases in Debug and the full phone-size
inspection case in a Release test build. Both build/install/test invocations must
pass. The explicit `TRAKTION_UI_TESTING` flag enables synthetic bootstrap in that
Release test binary only; normal Release builds exclude test input. See the task
note for the initial unoptimized reconstruction timeout. Both xcresults and
exported attachments are retained in `traktion-ios-verification`.
