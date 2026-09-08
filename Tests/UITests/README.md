# UI tests

`TRAKTIONLaunchTests.swift` belongs to the Xcode `TRAKTIONUITests` target, not
the SwiftPM test suite. The shared `TRAKTION` scheme launches the native iOS
app and checks the read-only shell's title, all workflow steps, status text,
horizontal bounds, scrolling, rotation, and larger text accessibility.

Run `bash scripts/verify-ios.sh` on macOS with Xcode and an installed iOS
simulator runtime. See `docs/runbooks/ios-development.md` for signing and
diagnostic output. Core reconstruction remains tested below the UI boundary;
these tests do not claim import, editing, persistence, or export exists.
