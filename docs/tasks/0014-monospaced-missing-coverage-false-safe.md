# Task: Monospaced missing-coverage false-safe

Status: reopened 2026-09-08; bounded engine repair complete and independently reviewed

## Finding

The first monospaced-code proxy repeated on a short period. When the middle
capture was removed, registration accepted a false overlap and produced a
composite. Task 0011 added a deterministic absolute-row gutter to the positive
fixture, but that changed the evidence rather than fixing this engine defect.
The original no-gutter pixels must remain a regression independent of the
anchored FixtureForge style.

## Reproduction

`Tests/Golden/MonospacedCoverageGapTests.swift` preserves the generator with
seed 5041, width 64, document height 240, and 96-row captures at origins 0
and 144. The missing middle capture begins at 72: remaining captures have a
48-row coverage gap. Reference full-pixel scoring under the existing default
thresholds finds one accepted forward overlap (57 rows, normalized mean error
0.0002773478, changed fraction 0) and one reverse overlap (30 rows, error
0.0005484069, changed fraction 0). Neither repeated-viewport-edge comparison
is byte-equal. The former supplied-order path therefore composes a false
135-row image with `strong` confidence.

## Bounded repair

ADR-018 requires a uniquely accepted near-exact supplied-order match to have
no acceptable reverse-direction overlap. Reverse evidence is checked with
the same scoring rules and the same joint's remaining sample/full-comparison
budgets. One or multiple accepted reverse placements produces the typed
`ambiguousOverlapDirection` failure, with no plan or composite; budget
exhaustion also fails closed. The raw pair probe does not recursively invoke
the direction check. A reverse-only triangle-inequality bound from RGBA row
sums proves impossible candidates cheaply enough to retain phone-scale
near-exact reconstruction under the unchanged shared allowance. Source visits
and summary comparisons are charged; storage covers only the searched regions.
Byte-exact behavior and the anchored fixtures stay intact.

The same review repairs task 0010's containment boundary: the repeated-chrome
guard applies only when the overlap is strictly shorter than both captures.
An exact shorter following suffix must not be compared with itself and
misclassified as fixed chrome.

This resolves bidirectional evidence ambiguity, not every possible coverage
gap. Repeated content with a valid supplied order can now refuse, and a gap
with only one acceptable direction still needs stronger independent evidence
or a future explicit review workflow. Do not describe a passing synthetic
corpus as universal proof that missing coverage is impossible.

## Allowed scope

- Registration engine and typed failure model.
- Focused golden regressions and failure serialization tests.
- This packet and ADR-018.
- No fixture replacement, threshold relaxation, UI changes, or dependencies.

## Acceptance criteria

- [x] Preserved pre-gutter missing coverage fails closed deterministically.
- [x] One or multiple acceptable reverse placements produces a typed refusal.
- [x] Reverse probes share the joint's sample and full-comparison budgets.
- [x] Aggregate bounds preserve exhaustive-oracle accepted candidates and
      limit source scans to the searched regions.
- [x] Anchored monospaced positive/missing controls retain their behavior.
- [x] Near-exact phone-scale reconstruction fits unchanged default budgets.
- [x] Exact full-height prefix and suffix containment both reconstruct.
- [x] Typed failure survives Codable with a stable code.
- [x] Existing core/golden suite and evaluation corpus pass unchanged.

## Verification

```sh
swift test -j 2 --filter MonospacedCoverageGapTests
swift test -j 2
swift run -j 2 traktion-lab evaluate --output /tmp/traktion-0014-evaluation.json
bash scripts/check-repository.sh
```

## Executed evidence

Linux Swift 6.0.3 validation used the integrated compiler driver because the
ordinary driver and SwiftPM test launcher intermittently crashed while
accounting for child processes in this host. The same crash reproduced on
unchanged `main`; the built XCTest executable runs successfully directly.

- Before the repair, the two added regression tests against `6cb004c`'s
  unchanged engine demonstrated the gap reconstruction and exact-suffix refusal.
- `swift build -c release --build-tests --use-integrated-swift-driver -j 2
  -Xswiftc -enable-testing`: passed.
- `.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest`:
  **103 tests passed, zero failures**. Near-exact 1170×2532 reconstruction
  including reverse proof completed in approximately 2.1 seconds.
- `.build/x86_64-unknown-linux-gnu/release/traktion-lab evaluate --output
  /tmp/traktion-0014-final-evaluation.json`: **43/43 cases passed**, zero
  false-safe, false-warning, wrong-failure, or nondeterministic outcomes.
- `bash scripts/smoke.sh`: passed with a transient exported `swift` shell
  wrapper adding `--use-integrated-swift-driver -j 2 -Xswiftc -enable-testing`
  to its build commands. The repository script was unchanged.
- `bash scripts/check-repository.sh` and `git diff --check`: passed.

The first shared-budget implementation failed the newly added near-exact
phone test; the bounded row-sum proof repaired this without changing the test
expectation or any limit. A partial debug suite was stopped in favor of the
complete optimized run above; it is not reported as a completed debug pass.

Writer: Codex engine agent. Reviewer: independent engine reviewer; no remaining
implementation or proof blocker after the bounded-region and oracle review.
