# Task: Peak-memory and throughput instrumentation

Status: implemented and independently reviewed; platform CI verification required before merge.

## Goal
Record actual process peak resident memory and input-pixel throughput for
phone-scale and very-long-canvas reconstructions on Linux and macOS.

## Why it matters
The engine retains input rasters and allocates a complete output raster.
Measured baselines are needed before setting mobile performance thresholds.
Process RSS also contains runtime and synthetic-source overhead; this task
documents that scope rather than claiming isolated engine allocations.

## Implemented behavior
1. `PeakMemorySampler` reads `getrusage(RUSAGE_SELF).ru_maxrss`, normalizing
   Linux KiB and Darwin bytes with typed failure and overflow handling.
2. Evaluation schema 4 has optional `performance` diagnostics. The standard
   corpus contains all previous 43 cases plus `performance-phone-3` and
   `performance-long-10`: 1170×2532 inputs, three/ten captures, 700-row overlap.
3. The first-run snapshot is taken before second-run and assessment allocations.
   Metrics name the process-lifetime scope, input RGBA bytes/pixels, precise
   reconstruction seconds, peak resident bytes, input amplification, and
   input pixels per second. Unavailable RSS is explicit, never substituted.
4. `--case` selects one known case for fresh-process baselines. CI retains
   full reports and isolated phone/long reports on both existing platforms.
5. `--max-memory-ratio` accepts a finite positive advisory and warns to stderr.
   It cannot change correctness verdicts or exit status. No memory/speed
   acceptance threshold is introduced before two releases of baseline data.
6. Nondeterminism bundles preserve each run's own diagnostic fields; varying
   measurements alone cannot make identical reconstruction results fail.

## Non-goals and scope
No engine, FixtureForge, shipping dependency, preview/export timing, or memory
optimization changes. Work is in Lab evaluation/CLI, diagnostic contracts and
tests, existing CI report generation/uploads, and supporting documentation.
The separate native scaffold task owns its UI/project/CI lane changes.

## Acceptance criteria
- [x] Report schema carries measured peak bytes, input amplification, and
      throughput for both instrumented shapes on Linux.
- [ ] macOS CI confirms Darwin sampling and retains the two measured cases.
- [x] Full-size cases reconstruct with original source pixels and no missing
      or duplicated rows in the complete corpus.
- [x] Measurement variability is excluded from behavioral determinism while
      all original 43 correctness cases remain covered.
- [x] Invalid/advisory CLI behavior is tested without changing gate semantics.
- [x] Independent source, metric-scope, and CI review found no blockers.
- [ ] Final Linux/macOS CI and required aggregator pass before merge.

## Verification evidence
Linux, Swift 6.0.3, optimized build in this cloud workspace:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
TRAKTION_GOLDEN_ARTIFACTS=/tmp/traktion-performance-goldens .build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest TraktionCoreGoldenTests.EvaluationPerformanceTests
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest TraktionCoreGoldenTests.NondeterminismArtifactTests
```

The initial complete suite passed 128 tests with zero failures. The final
diagnostic-only determinism test and per-run artifact assertions then passed
in the focused seven-test performance suite and four-test artifact suite.
The updated discovery contains 129 tests. The full release CLI passed 45/45
cases with zero false-safe, false-warning, wrong-failure, or nondeterminism.
Fresh-process phone and long cases also passed; an intentionally low advisory
printed a warning and returned success. Eleven invalid CLI requests were
rejected without writing a report.

The determinism test keeps all original 43 cases and exercises two smaller
instrumented variants with the same capture counts. Full phone/long geometry
is still exercised in the complete corpus test and release CLI. The ordering
test selects its eight ordering cases to avoid repeating unrelated benchmarks.
No original correctness assertion or engine limit was relaxed.

See ADR-019 and the verification runbook for units, scope, and reproduction.
CI remains the source of evidence for Darwin compilation/sampling and standard
platform test launch mechanics. Physical iPhone memory is not measured here.

## Ownership
Codex implementation; independent review of sampler, harness, CLI, and CI
report retention. Raw fixture and diagnostics remain synthetic-only.
