# Performance and native iOS continuation — 2026-09-08

Starting main: `f6ef26b61ab89cb192aab4d13a842487e21880a7` (PR #15).
Its main CI passed and no pull requests were open at the start of this work.

## Measured Linux baseline

Swift 6.0.3, optimized x86_64 Linux build in the cloud workspace. Each row
below came from a separate `traktion-lab evaluate --case` process, using
the same 1170×2532 inputs and 700-row overlaps. Both reconstructed exactly.
Timing is a single diagnostic observation, not a performance guarantee.

| Case | Input bytes | Process peak bytes | Peak MiB | Peak/input | Reconstruction seconds | Input MP/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `performance-phone-3` | 35,549,280 | 111,820,800 | 106.64 | 3.146 | 2.093 | 4.246 |
| `performance-long-10` | 118,497,600 | 314,433,536 | 299.87 | 2.654 | 9.648 | 3.071 |

These are process-lifetime peaks including the runtime and synthetic fixture
and source rasters. They do not measure an iPhone or isolate engine allocations.
The whole-corpus run also passed 45/45; its prior-case process history gives
different diagnostic values, as expected. See ADR-019 for exact metric scope.

The initial complete XCTest run passed 128 tests. A final determinism contract
and per-run artifact assertions passed in focused seven-test performance and
four-test artifact suites; final discovery contains 129 tests. Eleven invalid
CLI requests left no report, and a low advisory warned without failing the
successful case. The existing SwiftPM process-monitoring workaround remains
limited to this Linux host; CI runs the normal platform scripts.

## Platform CI measurements

[Run 34290310084](https://github.com/VASEYDEV/TRAKTION/actions/runs/34290310084),
head `046430a1a6c1d375377375fd7b63430921905b18`, passed all 129 XCTest tests
on each platform, both PNG smoke paths, the full 45/45 evaluation, and each
isolated baseline. Linux used Swift 6.0.3; macOS used Swift 6.1.2.
The complete suite runs in release mode with testable imports; the portable
debug build remains a compilation check. The first CI run was still in its debug
suites about 15 minutes after starting when the corrected head superseded it.
No assertion or full-size case was removed. Native UI tests use a debug app.

These observations are from each platform's fresh-process reports, not its
whole-corpus peak. Runner hardware and runtime differ; do not treat this table
as a controlled platform speed comparison or a physical-device memory limit.

| CI platform | Case | Process peak bytes | Peak/input | Input MP/s |
| --- | --- | ---: | ---: | ---: |
| Linux | `performance-phone-3` | 113,381,376 | 3.189 | 5.532 |
| Linux | `performance-long-10` | 316,862,464 | 2.674 | 4.068 |
| macOS | `performance-phone-3` | 97,746,944 | 2.750 | 5.580 |
| macOS | `performance-long-10` | 301,580,288 | 2.545 | 4.866 |

The run retains `traktion-evaluation-report` and
`traktion-evaluation-report-apple`, each with the full report and two isolated
case reports. The native lane and required aggregator also passed on this head.

## Native target

Task 0016 introduces an Xcode iOS application target using the local package,
the shared scheme, an isolated simulator smoke/UI test, and a required CI
lane. The existing shell adapts to phone width and larger text. Static project,
source, shell, and policy checks passed independent review. The first native
run built and launched the app but exposed a native/SwiftPM target-name
collision before test discovery. Renaming the native target to `TRAKTIONiOS`
fixed it while preserving the app product and shared scheme as `TRAKTION`.

[The successful native job](https://github.com/VASEYDEV/TRAKTION/actions/runs/34290310084/job/102275249216)
built, installed, launched, and passed both real XCTest UI tests on Xcode 16.4,
iPhone SE (3rd generation), iOS 26.2: two tests, zero failures, 59.549 seconds.
Portrait, landscape, and large-text assertions passed, with three screenshots
retained in the result bundle. Local screenshot download was blocked, so no
manual visual inspection is claimed. All four CI lanes and the required
aggregator passed. The final documentation revision must retain those checks
before PR #16 is merged.

Device signing is configurable but no team, certificate, App ID registration,
physical-device installation, or distribution build is claimed. Import,
reconstruction UI, editing, persistence, and export remain separate tasks.

## Next work

Tasks 0013 and 0016 are complete and removed from the active queue. Task 0017
is the reviewed, queued packet for PNG import, explicit order confirmation,
reconstruction, and result/typed-failure display. It includes source-integrity,
resource-admission, and single-worker cancellation contracts. Editor,
persistence, and export remain subsequent implementation work.

## Repository conditions

Main remains unprotected; all required CI lanes and independent review are
still required for this continuation. A read-only Git fetch/prune and GitHub
branch inventory during PR #16 verified that the three previously blocked
obsolete remote branches had been removed. Only `main` and the current PR
branch remained. The deletion actor was not established; the active cleanup
item is resolved from observed repository state. No account or protection
settings were changed and no authentication retry was needed. Temporary
branches/worktrees from this continuation are removed after verified merge.
