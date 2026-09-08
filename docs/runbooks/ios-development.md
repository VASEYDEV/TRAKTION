# Native iOS development

The Xcode target runs the existing read-only TRAKTION shell. Import,
reconstruction controls, inspection/editing, persistence, and export are
subsequent tasks. No production icon or physical-device release is claimed.

## Open and run
1. Use macOS with Xcode 16 or newer and an installed iOS 17+ simulator runtime.
   Xcode Settings > Components manages runtimes. The repository requires
   Swift 6; the selected Xcode must provide that toolchain.
2. Open `App/TRAKTION.xcodeproj` and choose the shared `TRAKTION` scheme.
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
4. Use `simctl install` and `simctl launch` on the resulting `TRAKTION.app`.
5. Run `xcodebuild test-without-building`; XCTest verifies title, workflow
   steps, read-only status, horizontal containment, scrolling, rotation, and
   larger text on the actual app.
6. Shut down and delete the dedicated simulator, preserving the test result.

Results live in a new run directory beneath `.traktion-local/ios-smoke`.
Set `TRAKTION_IOS_ARTIFACTS` to change that parent directory. Runs do not
overwrite each other's diagnostics. `TRAKTION.xcresult` contains XCTest
results; `build.log`, `launch.log`, `tests.log`, and toolchain/device JSON
support diagnosis. CI uploads those files as `traktion-ios-verification`.
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
