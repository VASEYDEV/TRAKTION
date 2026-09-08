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

## Native target

Task 0016 introduces an Xcode iOS application target using the local package,
the shared scheme, an isolated simulator smoke/UI test, and a required CI
lane. The existing shell adapts to phone width and larger text. Static project,
source, shell, and policy checks passed independent review. Native execution
must be established by macOS CI before merge; this note does not substitute
Linux parsing for an actual iOS build or launch.

Device signing is configurable but no team, certificate, App ID registration,
physical-device installation, or distribution build is claimed. Import,
reconstruction UI, editing, persistence, and export remain separate tasks.

## Repository conditions

Main remains unprotected; all required CI lanes and independent review are
still required for this continuation. The three obsolete remote branches
documented in the earlier continuation note remain blocked by unavailable
delete-ref capability and GitHub's rejected browser password sign-in. Their
heads must be rechecked before deletion. No account or protection settings
were changed, and there is no repeated authentication attempt in this work.
