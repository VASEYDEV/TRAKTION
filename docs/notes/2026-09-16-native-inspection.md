# Native pixel and joint inspection — 2026-09-16

Task 0019 continues from clean main `920b950` (PR #18). There were no open PRs
and the only remote branch was main. Codex owns implementation; a separate
read-only reviewer checked pixel coordinates, memory ownership, main-actor
responsiveness and accessibility under the task's explicit independent-review
requirement. Core registration, thresholds, codec contracts and originals are
unchanged. See [ADR-022](../adr/ADR-022-bounded-pixel-inspection.md).

## Local verification

Swift 6.0.3 / Ubuntu 24.04, release:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
TRAKTION_GOLDEN_ARTIFACTS=/tmp/traktion-inspection-goldens .build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
bash scripts/check-repository.sh
bash -n scripts/verify-ios.sh docs/notes/inspection-probe/run.sh
git diff --check
.build/x86_64-unknown-linux-gnu/release/traktion-lab evaluate --output /tmp/traktion-inspection-evaluation.json
```

The release suite passed **177 tests, zero failures**, in 29.436 seconds.
Repository/shell/whitespace checks passed; evaluation passed **45/45**, with zero
false-safe, false-warning, wrong-failure or nondeterministic cases. Twelve
new tests cover independent source-coordinate crops, all original/result joint
regions, 19,020-row viewport bounds, downsampling/magnification, final pixels,
invalid requests, stable capture IDs despite duplicate basenames and reordered
arrays, admission overflow, coalesced requests, cancellation-ignoring workers,
and reset/replacement/navigation clearing state.

An initial test setup expected an origin at the left edge after center-preserving
zoom; the test now explicitly pans left before checking its independent movement.
A SwiftPM attempt also hit the host's known libdispatch `/proc/<thread>/stat`
accounting crash; the unchanged command succeeded on retry. No production code
or test assertions were weakened to work around that host crash.

The independent reviewer identified final-row loss at fractional magnification.
The corrected clamp aligns the last sampled coordinate. The regression asserts
the last RGBA pixel at 1.1× in both axes. The reviewer independently reproduced
the original 19,020-row case and ran all seven model tests successfully after
correction. Capture IDs were also added to disambiguate identical filenames.

## Resource probe

Run `bash docs/notes/inspection-probe/run.sh` after the release build. It reuses
the separate synthetic PNG generator (1170 × 2532, ten captures, overlap 700,
seed 51), then starts a fresh synchronous worker process. Captures, thumbnails,
full result and preview remain retained while it renders 960 × 720 viewports at
top/middle/bottom/fit. Prior/new frames overlap within the declared reservation.
All ten input PNG SHA-256 values are checked after the probe.

Measured [raw report](inspection-probe/long-report.json): retained workspace with
preview-copy allowance **216,269,648 B**, inspection reserve **25,165,824 B**,
admitted total **241,435,472 B**, below the unchanged 268,435,456 B ceiling.
Actual maximum frame array: **2,764,800 B**, independent of the 89,013,600 B full
result. Top/middle/bottom/fit took 4.820/4.779/9.241/1.710 ms in this single run.
Process-lifetime peak before/after inspection was 239,915,008/240,197,632 B;
current RSS snapshots were 240,132,096/240,332,800 B. Different kernel accounting
and sample times can disagree slightly; these are observations, not bounds.
All ten input hashes matched. This probe measures Linux raster work and process RSS;
it does not instantiate SwiftUI, CGImage, the model scheduler or a GPU. Apple
simulator execution and physical-device memory are separate evidence.

## Native verification

Two additional simulator tests cover a genuine 1170 × 6196 reconstruction's 1:1
view, horizontal/vertical pan, final-region navigation, joint 2 names/confidence
and exact seam coordinates, both original views, portrait/landscape, closing and
reopening without stale selection, reset, and XXXL accessibility controls. The
five existing PNG workflow/failure tests remain enabled.

Apple package, PNG and iOS simulator runs are pending publication. Screenshots
are retained by XCTest; this note does not claim manual visual inspection until
those artifacts are retrieved and reviewed. Physical-device signing/memory,
VoiceOver speech, third-party Files-provider selection and export are not tested
by this inspection change.
