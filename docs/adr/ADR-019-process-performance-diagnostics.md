# ADR-019: Process peak memory and reconstruction throughput diagnostics

Status: accepted for task 0013.

## Context

The core owns complete input/output rasters, but its previous evidence was
limited to execution bounds and millisecond timing. Mobile memory limits need
measured baselines before an acceptance threshold can be justified.

## Decision

Evaluation schema 4 adds an optional `performance` object for instrumented
cases. The standard corpus now contains 45 cases, ending with three and ten
1170×2532 captures with 700-row overlaps. All existing correctness cases and
their verdicts remain. The new cases use the existing deterministic generator
and shipping supplied-order engine without changing either.

`PeakMemorySampler` reads `getrusage(RUSAGE_SELF).ru_maxrss`. Normalize Linux
KiB by multiplying by 1024; Darwin already reports bytes. Reject nonpositive
readings and integer overflow. Sampling failure is explicit missing data plus
an error string; it never becomes a fabricated zero or a reconstruction failure.

The report uses the first reconstruction's snapshot, taken before the second
run, source assessment, or artifact writing. The memory scope is explicitly
`process-lifetime-high-water-after-reconstruction`. It includes runtime,
fixture/source rasters, and prior process activity. It is neither current RSS,
an allocation delta, nor memory attributable solely to the engine. Do not
subtract two high-water marks to claim incremental memory usage. A second
observation retained for nondeterminism has its own diagnostics and may also
include the still-live first result.

`inputBytes` is the sum of actual input RGBA array lengths, including overlap.
`inputAmplification` divides process peak bytes by that sum. Throughput is
`inputPixelCount / reconstructionSeconds`, using full `ContinuousClock`
precision, not rounded integer milliseconds. The timed region is the engine
call; generation, diagnostics, assessment, and export are excluded. It measures
the supplied pixel workload per second, not the number of pixels the algorithm
actually inspects. For a refused reconstruction this is attempted-workload
throughput, not produced-output throughput; baseline comparisons use successful
cases. A zero-duration or empty-input sample has no throughput ratio.

`--case <standard-case-name>` runs one case in a fresh CLI process. Both CI
platforms retain the complete report plus separate phone/long reports from
fresh processes. These still include the runtime and synthetic fixture, and
are not measurements on an iPhone. Compare like platform, build mode, workload,
and process scope.

`--max-memory-ratio` accepts only a finite positive number, emits warnings to
stderr, and never changes the report verdict or exit code. No memory or speed
threshold enters the required gate until at least two releases provide data.
Memory and timing diagnostics are excluded from behavioral determinism checks;
outcomes, plans, pixels, orders, and correctness metrics remain authoritative.

## Verification

Unit contracts cover raw units/overflow, sampling failures, precise/zero-time
throughput, actual input-byte denominators, Codable, and advisory boundaries.
The full-size standard corpus validates both new reconstruction shapes. The
report determinism test retains the original 43 cases and uses smaller rasters
with the same capture counts for the two new diagnostic cases; full-size cases
remain in the complete-corpus test and CLI gates.

The portable gate retains a debug build and runs the entire XCTest suite with
release optimization and testable imports. Full phone-sized rasters made the
first debug CI suites exceed 15 minutes. No test is filtered or conditionally
skipped: optimized runtime correctness is the target, while the portable
debug configuration receives compilation coverage. Native UI tests continue
to run a debug app. The separate release CLI corpus remains required.

## Sources

- [Linux getrusage(2)](https://man7.org/linux/man-pages/man2/getrusage.2.html):
  process scope and KiB-valued `ru_maxrss`.
- [Apple XNU getrusage(2) source](https://github.com/apple/darwin-xnu/blob/main/bsd/man/man2/getrusage.2):
  byte-valued `ru_maxrss`. Apple's archived web manual has conflicting units;
  the platform source documents the Darwin contract used here.
