# Task: Native iOS target and simulator gate

Status: done — independently reviewed and verified in PR #16.

## Goal
Make the existing read-only SwiftUI shell an actual iOS application target,
using the same local package modules as the diagnostic tools.

## Starting point
Before this task, the repository had a SwiftPM preview executable, but no Xcode app project,
shared simulator scheme, app UI launch test, or device-signing configuration.
The shared view imposed a 520-point minimum width that did not fit an iPhone.

## Required behavior
- Check in an iOS 17+ Xcode project and shared `TRAKTION` scheme without a
  project generator or external package dependency.
- Reuse `App/TRAKTION/Sources/TRAKTIONApp.swift` and the local `TraktionUI`
  and `TraktionCore` products. Keep reconstruction out of UI code.
- Build, install, launch, and test the shell in a dedicated iPhone simulator.
- Require the simulator lane in the existing CI result aggregator.
- Allow developer-owned signing settings without committing a team,
  provisioning profile, certificate, or credentials.
- Keep the existing shell readable on iPhone and at larger text sizes.

## Non-goals
Photo import, reconstruction UI, editing, persistence, export, production
icons, physical-device verification, App Store distribution, and new branding.

## Acceptance criteria
- [x] Xcode resolves the repository's local package and builds the iOS app.
- [x] The shared scheme builds and executes a real XCTest UI test target.
- [x] Simulator smoke installs and launches the app, then verifies the shell
  content and horizontal bounds in portrait, landscape, and larger text.
- [x] CI requires the iOS simulator result and retains test diagnostics.
- [x] Device signing and exact simulator verification steps are documented.
- [x] Existing repository policy checks remain green.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash -n scripts/verify-ios.sh
bash scripts/verify-ios.sh  # macOS, Xcode, installed iOS simulator runtime
git diff --check
```

## Writer and reviewer
Codex owns the native scaffold branch. Independent review and macOS CI verify
the project, simulator script, and application launch before merge.

## Portable verification evidence
On Linux, Foundation parsed the OpenStep project; all project object
references, source paths, local package paths, shared scheme references, and
required CI result wiring were checked. Swift frontend syntax parsing,
`bash -n scripts/verify-ios.sh`, repository checks, and `git diff --check`
passed. Running `verify-ios.sh` on Linux failed explicitly with exit 1 as
intended. Independent static review found no remaining blockers. These portable checks are supplemental; the actual Xcode build and simulator
execution are established below.

## Initial macOS CI evidence
[Run 34289148563, native job 102271538317](https://github.com/VASEYDEV/TRAKTION/actions/runs/34289148563/job/102271538317)
used Xcode 16.4 (16F6),
macOS 15.7.9 arm64, and an iPhone SE (3rd generation) with iOS 26.2. The app
and UI test bundle built successfully, and `simctl` installed and launched
`dev.vasey.traktion`. XCTest then failed before executing tests because its
app lookup used the extensionless `TRAKTION` preview-product path. The
native target is now disambiguated as `TRAKTIONiOS`, with the app product and
scheme still named `TRAKTION`. The successful subsequent run below verified this repair
and the remaining UI acceptance criteria.

## Successful native verification
[Run 34290310084, native job 102275249216](https://github.com/VASEYDEV/TRAKTION/actions/runs/34290310084/job/102275249216)
verified head `046430a1a6c1d375377375fd7b63430921905b18` on Xcode 16.4 (16F6),
iPhone SE (3rd generation), iOS 26.2. `build-for-testing` passed, and the app
installed and launched. XCTest then executed both tests with zero failures:
portrait/landscape in 35.952 seconds and large text in 23.597 seconds.
`TEST EXECUTE SUCCEEDED`, `IOS SIMULATOR VERIFICATION: PASS`, and the required
aggregator all passed. Three screenshot attachments were retained in the
result bundle; local artifact-download access prevented manual visual
inspection, so layout evidence is the executed UI assertions and retained
attachments. Physical-device signing remains outside this task.

The final documentation revision must retain all required checks before merge.

## Architecture
See `docs/adr/ADR-020-native-ios-target.md` and
`docs/runbooks/ios-development.md`.
