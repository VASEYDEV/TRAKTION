# Task: Native iOS target and simulator gate

Status: implemented and independently reviewed; macOS simulator verification pending

## Goal
Make the existing read-only SwiftUI shell an actual iOS application target,
using the same local package modules as the diagnostic tools.

## Current behavior
The repository has a SwiftPM preview executable, but no Xcode app project,
shared simulator scheme, app UI launch test, or device-signing configuration.
The shared view imposes a 520-point minimum width that does not fit an iPhone.

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
- [ ] Xcode resolves the repository's local package and builds the iOS app.
- [ ] The shared scheme builds and executes a real XCTest UI test target.
- [ ] Simulator smoke installs and launches the app, then verifies the shell
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
intended. Independent static review found no remaining blockers. These checks
do not substitute for the pending Xcode build and simulator tests above.

## Architecture
See `docs/adr/ADR-020-native-ios-target.md` and
`docs/runbooks/ios-development.md`.
