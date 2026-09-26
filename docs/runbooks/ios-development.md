# Native iOS development

The Xcode target imports 2–10 opaque equal-width PNG captures from Files,
requires explicit top-to-bottom order confirmation, and shows local supplied-order
reconstruction or a typed failure, pixel/joint inspection and reversible seam
adjustment, local project save/open and committed full-resolution PNG export.
No production icon or physical-device release is claimed.

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
   release CLI process, install the app, and copy capture PNGs into private
   `Library/Application Support/UIFixtures` in the dedicated simulator. Source
   truth/manifests stay outside it. The script also seeds one deliberately corrupt
   synthetic project in Documents for the real Files refusal test.
5. Launch and run all small-input Debug XCTest scenarios for real import, supplied order,
   reconstruction/refusals, reset, rotation, larger text (including inspection),
   deliberate seam apply/cancel/undo/redo, real Files project save/reopen after
   app termination, save/open cancellation, corrupt-project refusal and
   same-name refusal preserving both the changed workspace and original saved file.
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
Build, launch and test logs retain stderr as well as stdout. Before a failed
run's dedicated simulator is deleted, `collect-ios-diagnostics.py` requests the
last 25 minutes of TRAKTION, SpringBoard and document/FileProvider service logs.
Collection stops after 20 seconds or 8 MiB per output file. The service log,
error log and status JSON distinguish collected, unavailable, failed, timed-out
and size-limited evidence. Collection failure never replaces the original
verification failure. These logs come only from the dedicated simulator seeded
with synthetic fixtures, not a personal simulator or physical device.
Screenshots are attached to `TRAKTION.xcresult`; test assertion success and
actual human/agent visual inspection must be reported separately. These tests
do not automate third-party Files provider selection or physical-device use.
Build products remain under the run's `DerivedData` directory and are not
uploaded. Missing prerequisites, build failures, launch failures, and failed
UI assertions make the lane and required aggregator fail.

Issue [#23](https://github.com/VASEYDEV/TRAKTION/issues/23) records one intermittent
blank system Files sheet during PNG export. The unchanged rerun and subsequent
main run 35916314107 passed; a root cause is not established. Files failure
attachments include the test name and UTC timestamp for service-log correlation.
Diagnostics do not repair or suppress the failure. Assertions, wait durations and
the complete native test inventory remain mandatory; no automatic retry was added.

On Linux, `bash -n scripts/verify-ios.sh` checks shell syntax and
`bash scripts/check-repository.sh` checks repository policy. Neither runs
Xcode, compiles SwiftUI, or establishes that the app boots.

## Ordinary device Release verification

On a Mac with Xcode, run:

```sh
python3 scripts/verify-ios-release.py
```

This builds the shared scheme's ordinary Release for `generic/platform=iOS` in
a unique `.traktion-local/ios-release/run.*` directory. Signing is disabled for
this invocation only. It does not enable the simulator test fixture flag.
The required CI job `verify / iOS device Release` runs the same command separately
from native UI verification; both jobs must pass the existing required aggregate.

The checker validates effective Release/device settings, optimization, bundle ID,
version and minimum OS, then checks the built app's metadata, arm64 architecture,
iPhone/iPad support and exclusion of test bundles, fixture resources and compiled
fixture-bootstrap markers. It refuses `DEBUG` or `TRAKTION_UI_TESTING`, including
Swift `-D` flags. CI retains `build.log`, settings errors, Xcode version,
allowlisted effective settings and `validation.json`
(or `failure.txt`) as `traktion-ios-device-release`; it does not upload app binaries.
Use `--artifacts /absolute/path` to select a different diagnostics parent.

This is an unsigned device-SDK build, not an installable signed alpha, an archive
validated for App Store distribution, or proof of device runtime behavior.

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
signing flow. After configuring your actual team and bundle identifier, the
same checker can explicitly build for the connected device identifier shown
in Xcode's Devices and Simulators window:

```sh
python3 scripts/verify-ios-release.py --signed-device YOUR_CONNECTED_DEVICE_ID
```

The command refuses absent/invalid team settings or disabled signing. It retains
normal automatic-signing behavior without enabling provisioning updates or device
registration. Existing signing assets must already permit the build. After building,
it verifies the signature, matching team and embedded profile. It does not install,
launch, register an App ID, accept agreements, export an IPA or upload anything.
Use Xcode to install/run the built app, then record physical-device QA separately.
The command's existence and orchestration tests do not establish a signed build.

Do not add account credentials, private keys, certificates,
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
Select a joint to see both filenames/positions, confidence, overlap and seam boundaries;
choose Result, First original or Second original to inspect their unchanged
pixels. Done clears the inspection session; reopening begins at the result.

The inspection gate adds a 1170 × 6196 three-capture PNG fixture and tests 1:1,
pan, joint/source selection, portrait/landscape, reopening/reset and larger text.
The 1170 × 19020 ten-capture Linux probe measures the same bounded raster renderer
while retaining the full workspace; it is not a device memory claim. Commands
and scoped evidence: [inspection note](../notes/2026-09-16-native-inspection.md).

Native verification runs all small-input UI cases in Debug and the full phone-size
inspection case in a Release test build. Both build/install/test invocations must
pass. The explicit `TRAKTION_UI_TESTING` flag enables synthetic bootstrap in that
Release test binary only; normal Release builds exclude test input. See the task
note for the initial unoptimized reconstruction timeout. Both xcresults and
exported attachments are retained in `traktion-ios-verification`.

## Deliberate seam adjustment

Select a proven joint in the inspector and choose **Adjust this seam**. Nudge the
boundary within the displayed permitted overlap, compare the original sources,
and apply or cancel. Undo/redo restores committed boundaries and pixels;
closing/reopening the inspector keeps committed history while discarding a draft.
Reset, replacement and capture-order changes clear that workspace's edits.
The preview samples original source strips through the core without retaining a
second full-size composite. Project saving preserves committed seams as described
below; committed PNG export is described after local projects.

## Local projects

After reconstruction, close the inspector and choose **Save project**. Enter a
name of 1–80 letters, numbers, spaces, hyphens or underscores; `.traktion` is
added automatically. Some Unicode characters require a shorter name to fit the
filesystem filename limit; the app asks for a valid name before attempting a save.
Choose **Choose folder**, then confirm the destination in
the real Files folder picker. **On My iPhone → TRAKTION** uses local storage.
Each save creates a new file. If any item already uses the selected name, choose
another unused name; existing projects, unrelated files and symlinks stay untouched.

Choose **Open project** and select a `.traktion` file in Files. The app validates
the original PNGs and reproduces the saved automatic evidence before replacing
the workspace. Names/order, committed seam positions and modified status return;
undo/redo starts with the new session. A failed or cancelled open keeps existing
captures and committed edits. Uncommitted inspector drafts cannot be saved.

Cancelling the name or Files dialog leaves the workspace unchanged. On iOS
versions without a visible folder-picker Cancel button, swipe the folder sheet
down to dismiss it. During a worker operation, **Cancel** waits for the worker
to drain. Cancellation before
save publication leaves no new destination; a completed atomic save is
reported as saved even if cancellation follows it. Cleanup errors remain visible,
including the distinct case where the project saved but private staging remains.

Projects contain original PNG bytes and metadata. The app makes no network
request, but a selected Files provider may synchronize its storage. Providers
without same-filesystem hard-link support are refused; choose the local TRAKTION
folder if the destination is unsupported. Private staging stays outside the
selected folder so another folder writer cannot substitute the save source. Third-party
provider compatibility and physical-device behavior are not established by CI.
The app exports its project UTI for in-app selection; external Files tap-to-launch
handling is not registered. The macOS SwiftPM preview uses a data-file picker and
validates the selected file's project signature.

[ADR-024](../adr/ADR-024-local-project-container.md) defines format compatibility,
the separate encoded/raster limits and large-project admission evidence. Resetting
a large current workspace may be necessary before opening another large project.

Both native phase logs are checked against the source test inventory after
Xcode succeeds. Missing, silently unselected, failed or repeated cases fail the
gate, as do timeout/restart markers followed by passing records. The repository
lane exercises this guard with Python standard-library tests.

## PNG export

After reconstruction and any applied seam edits, choose **Export PNG**, enter a
name, and choose a folder in Files. Prefer **On My iPhone → TRAKTION**. Existing
names are refused; there is no overwrite mode. Export includes committed seams,
not an uncommitted inspector draft or the scaled preview. Source files, saved
projects and undo/redo remain unchanged. Export remains offline.

Cancel before publication prevents a destination file. Reset clears the workspace
but keeps the worker occupied until export drains. If publication already happened,
the exported filename remains reported after reset or late cancellation. Cleanup
failure explicitly reports whether the PNG was committed. Unsupported providers
and cross-filesystem locations are refused without a non-atomic copy fallback.

The encoder supports up to 67,108,864 output pixels, 1 MiB per RGBA row and 300 MiB
encoded output, subject to the current workspace plus bounded scratch budget.
Capture decoding retains its smaller 16,777,216-pixel limit. PNGs use stored
DEFLATE blocks and can be large. See ADR-025 for the exact admission contract.

Native test `testPNGExportUsesFilesAndRefusesCollisionWithoutChangingResult`
checks the actual name dialog, Files cancellation, local folder selection, export
receipt and collision refusal. Package tests separately decode the exported PNG
and compare it with source-pixel oracles, including committed near-exact seams.
Physical-device storage providers and memory behavior remain release checks.
