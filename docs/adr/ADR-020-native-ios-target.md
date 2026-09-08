# ADR-020: Checked-in iOS app target and simulator verification

Status: Accepted
Date: 2026-09-08
Task: 0016

## Context
The shared reconstruction packages and macOS preview executable are verified,
but a SwiftPM executable is not an iOS app bundle. The project needs a native
target before import and editing can be developed and tested on iPhone.

## Decision
Check in `App/TRAKTION.xcodeproj` and its shared `TRAKTION` scheme. The app
compiles the existing entry point and links the repository's local
`TraktionUI` and `TraktionCore` package products. The iOS deployment minimum
stays aligned with `Package.swift` at iOS 17. Swift 6 is required. No project
generator, binary dependency, copied core implementation, or remote package
is introduced.

The existing shell stays read-only. Its content scrolls, the desktop minimum
width applies only on macOS, and the iOS axis selector uses a menu so its
disabled future option does not consume most of an iPhone's width. Stable
accessibility identifiers support real application UI tests in portrait,
landscape, and larger text. UI code still does not reconstruct pixels.

`scripts/verify-ios.sh` uses the selected Xcode and an installed iOS 17+
runtime. It records the actual toolchain and chooses an available compatible
iPhone device type, then creates a dedicated simulator. It builds the app and
tests without signing, explicitly installs and launches the app, and runs
XCTest UI assertions. Cleanup only shuts down/deletes that newly created
simulator. No existing simulator is erased or repurposed. Missing Xcode or
runtimes is a failure, never a skipped green result.

The CI iOS lane is a dependency of `verification / required`. Test results,
toolchain details, and build logs are retained. A passing Linux SwiftPM build
or static project inspection is not evidence that the native target runs.

## Signing boundary
Automatic signing remains enabled for normal device builds, with no default
development team. An ignored `Signing.local.xcconfig` or command-line build
setting supplies the developer's team and optional registered bundle ID.
Simulator verification alone overrides `CODE_SIGNING_ALLOWED=NO`; this does
not change device signing or authorize certificate creation, provisioning,
App Store upload, or account changes. The default development bundle ID is
`dev.vasey.traktion`; registration and distribution identity are unverified.

## Consequences
- The same source tree provides the macOS preview and actual iOS app shell.
- CI detects broken app linking, launch failures, and basic layout overflow.
- The conventional project file must be maintained alongside source/target
  changes, without requiring a generator to open the project.
- An installed simulator runtime is required; the lane logs the runtime
  rather than silently downloading one or assuming a model/version exists.
- No production icon is fabricated. Device signing, approved app artwork,
  physical-device QA, and distribution remain explicit follow-ups.
- Passing the launch tests does not establish photo import, reconstruction
  interaction, correction, persistence, export, or real-world app readiness.

## References
- [Apple: Organizing code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [Apple: Building and testing from the command line](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [Apple: Running an app on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
