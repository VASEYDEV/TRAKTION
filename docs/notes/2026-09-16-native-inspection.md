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

The initial release suite passed **177 tests, zero failures**, in 29.436 seconds.
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
or test assertions were weakened to work around that host crash. The final local
release suite, including the tall-image regression and capture-position checks,
passed **178 tests, zero failures**, in 28.380 seconds. All 13 focused inspection
tests also passed; the reviewer independently reran the position/pixel case.

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

[Initial CI run 35158214111](https://github.com/VASEYDEV/TRAKTION/actions/runs/35158214111)
passed repository, Linux and Apple package/ImageIO gates: 177 tests each and
45/45 evaluations, plus isolated phone/long performance cases. Xcode 16.4 built
and launched the native app on iPhone SE (3rd generation), iOS 26.2. Six UI tests
passed, including the new XXXL inspection test (72.376 s). The full-size phone
case failed because its Debug reconstruction was still busy after 107 seconds;
its dependent inspection assertions never ran. The test did not observe a typed
reconstruction failure, and this is not evidence of a successful phone UI flow.

The native script now preserves those six Debug UI cases and runs the exact
same full-size inputs and inspection assertions in a separate Release test
build. This matches the existing portable gate's optimized full-size policy;
there is no fixture reduction, timeout increase or skipped overall test. The
explicit `TRAKTION_UI_TESTING` compilation flag enables the synthetic bootstrap
only in that Release test build; ordinary Release apps still exclude it.
Localized numeric expectations follow Foundation's formatting used by SwiftUI.
Both xcresults and exported screenshots are retained. The completed run and
actual screenshot review are recorded below. Physical-device signing/memory,
VoiceOver speech, third-party Files-provider selection and export are not tested
by this inspection change.

## Tall-image review follow-up

GitHub review identified a fixed 1/65536 zoom floor that could prevent Fit from
covering extremely tall, narrow admitted rasters. The viewport now accepts every
positive finite zoom through 16×; the model derives its zoom-out minimum from the
actual dimensions. A 1 × 262145 raster with a 2 × 2 viewport reproduces the old
failure without excessive allocation. The regression covers initial Fit, return
from 1:1, and further zoom-out clamping. Very small percentages use six significant
digits so a valid scale does not display as zero. The independent reviewer
confirmed the geometry/resource fix and reran all 13 focused inspection tests.

## Native interaction correction

[Revised run 35159289876](https://github.com/VASEYDEV/TRAKTION/actions/runs/35159289876)
passed all six Debug cases (283.948 s) and completed the same full-size phone
reconstruction in Release. The optimized inspection case reached all joint,
original-source, rotation and navigation checks, but failed its first down-pan
assertion: the generic ScrollView swipe was inside the canvas, so it intentionally
panned pixels to the bottom instead of revealing the control. Test scrolling now
uses the inspector margin; an explicit image swipe separately asserts that pixels
pan. Inputs, coordinate assertions and timeouts remain unchanged.

## Visual review

The second run's exported `Large text joint evidence` screenshot was retrieved
and actually inspected. At XXXL, raw capture UUIDs dominated the screen. The
inspector now shows supplied-order capture positions beside the filenames,
resolved through the same stable IDs. A reversed-array/duplicate-basename unit
case verifies these positions, and the native test asserts joint 2's capture 2
to capture 3 label. Full identifiers remain implementation metadata.

## Completed gate and final review

[Run 35160746034](https://github.com/VASEYDEV/TRAKTION/actions/runs/35160746034)
passed all required checks at head `80e8c79`: repository, Linux, Apple package/PNG,
iOS simulator and aggregate verification. Linux and Apple each ran 178 tests,
45/45 evaluations and the isolated performance cases. The six Debug UI tests
passed in 197.459 s; the unchanged full-size Release inspection case passed in
58.907 s, including explicit image dragging, direction controls, joint/source
checks, rotation, reopening and reset. The Release script also requires that
exact test's passing record, preventing a stale selector from accepting zero tests.

The exported 1:1 bottom and original-source portrait screenshots were retrieved
and visually inspected: pixel view, zoom/coordinates, controls and exact joint
evidence are visible. The landscape attachment was also inspected but was clipped
with a black region despite passing window-orientation and containment checks.
Its PNG has a rotated screenshot orientation tag; inspecting its unchanged raw
pixels confirmed this was not merely the image viewer's presentation. The test
now captures `XCUIScreen.main` rather than the rotated application's bounds.
That evidence-capture change and the shorter capture labels receive another full
required gate. Final-head results and post-change screenshot review are recorded
in [PR #19](https://github.com/VASEYDEV/TRAKTION/pull/19) before merge; this note
does not present the clipped attachment as a clean landscape visual pass.

Task 0019 is complete once those final merge gates pass. The task index and roadmap
advance to task 0020; historical completed/superseded packets remain evidence,
not queued work. Delete the feature branch after its tree is preserved on main.

The next [run 35161855267](https://github.com/VASEYDEV/TRAKTION/actions/runs/35161855267)
again passed repository/Linux/Apple gates, but the XXXL test exposed the reveal
helper alternating large up/down drags around the region picker. Its final
hittability assertion failed; XCTest's subsequent tap scrolled the same picker
into view and the joint checks continued. The inspector helper now moves toward
the target's center with a bounded distance, keeping the drag in the margin and
retaining all assertions and retry limits. The script also exports attachments
on failure while preserving its original exit status, so a failed case does not
hide visual diagnostics inside an xcresult bundle. Final-head native validation
is still required; the earlier green run does not substitute for it.
Independent review found no blocker in the revised geometry or shell cleanup.
An isolated execution of the actual cleanup function preserved both successful
and failing original exit codes even when diagnostic export/cleanup failed;
shell syntax, repository policy and whitespace checks passed.

## Final closure — 2026-09-17

[PR #19](https://github.com/VASEYDEV/TRAKTION/pull/19) was merged at
`c279264e9d7e552561a7e52ec5368df17e99af84`; its feature branch was deleted.
The final [PR run 35162902248](https://github.com/VASEYDEV/TRAKTION/actions/runs/35162902248)
and subsequent [main run 35163939876](https://github.com/VASEYDEV/TRAKTION/actions/runs/35163939876)
passed all five jobs. Main ran 178 XCTest cases on each core platform, the
45-case evaluation corpus on each, six Debug UI cases and one full-phone Release
UI case. The final portrait and landscape attachments were actually inspected;
the full-screen landscape capture no longer has the earlier black clipping region.
Task 0019 is complete. Earlier pending statements above preserve the chronology.
