# Runbook — verification gates

## Portable repository check

```bash
bash scripts/check-repository.sh
```

This validates required project files, unfilled placeholders, the compact `CLAUDE.md`
shim, committed environment/private-key material, and every tracked JSON document. It
searches tracked files only, so generated SwiftPM/Xcode output cannot create false hits.

## Platform-neutral Swift verification

```bash
bash scripts/verify-core.sh
```

This requires Swift 6, parses the package manifest, builds every SwiftPM target, and runs
the unit, golden, failure-path, determinism, performance-shape, and conditional PNG tests.
Pure-Swift PNG tests run on Linux; Apple-only ImageIO parity tests compile and run on macOS.

## Complete Apple gate

```bash
bash scripts/gate.sh
```

The complete gate requires macOS. It runs the repository check and Swift suite, then:

1. builds release `fixture-forge` and `traktion-lab` executables;
2. generates three synthetic PNG captures and untouched source truth;
3. reconstructs the captures through the shipping core;
4. writes the composite, deterministic manifest, and two joints' JSON/difference PNGs;
5. decodes the source and composite and requires exact RGBA equality.

The smoke path also verifies recursive diagnostics-directory creation and forces a late
manifest-publication failure to prove that partial artifacts are removed before exit.
Since task 0008 it additionally runs the same captures shuffled under `--order exact`
(composite byte-identical to the supplied-order run, twice), a two-capture coverage gap
(typed `sequenceOrderNotFound` failure manifest, no composite), and an unknown `--order`
value (usage error, nothing written). Since task 0009 it also generates the degraded
control set and proves that `--order exact` refuses it (typed manifest) while
`--order near-exact` reproduces the supplied-order composite byte for byte.

## Evaluation gate

```bash
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

Runs the standard 43-case corpus twice per case and exits non-zero on any false-safe,
false-warning, wrong-failure, or nondeterminism. The summary line reports the
EVALUATION.md ordering metrics (correct-sequence, duplicate-identification, and
missing-capture-detection counts) across the exact and near-exact ordering cases.

Successful completion ends with `GATE: PASS (repository · Swift build/tests · Apple PNG smoke)`.

## Synthetic failure evidence

```bash
swift run traktion-lab evaluate --output /tmp/report.json --artifacts-dir /tmp/evaluation-artifacts
# Include passing cases and typed refusals for deliberate inspection:
swift run traktion-lab evaluate --output /tmp/report-all.json --artifacts-dir /tmp/evaluation-all --all-artifacts
TRAKTION_GOLDEN_ARTIFACTS=/tmp/golden-artifacts bash scripts/verify-core.sh
```

Use fresh destinations; the report must be outside the artifact directory.
Passing evaluation cases create no bundles by default. A reconstructed case
retains `expected.png`, `actual.png`, `difference.png`, `manifest.json`, and
`joints/joint-NNN.json` plus absolute-difference PNGs. Size mismatches preserve
both original rasters and explicitly record the common top-left diff extent.
A typed refusal has no composite or joint plan: its manifest records that
those files are unavailable instead of inventing images.

Wrapped golden tests retain their exact input arrays until XCTest determines
whether an assertion failed. The helper covers cases with known genuine
source truth; new tests should use `GoldenArtifactTestCase.goldenReconstruct`
with that source and the actual inputs. Ambiguous examples with no known true
source must not manufacture an expected image merely to fill a bundle.
Artifacts remain synthetic-only. Both CI platforms upload their dedicated
failure directories only on failure; the evaluation JSON is always retained.

## CI lanes

`.github/workflows/ci.yml` runs on every pull request and push to `main`:

- `verify / repository` on Ubuntu;
- `verify / core (Linux)` in the official Swift 6 Ubuntu image;
- `verify / Apple package and PNG smoke` on `macos-15`;
- `verification / required`, an `always()` aggregator that fails unless all three pass.

On Apple-smoke failure, CI retains only the generated synthetic fixture, composite,
manifest, and diagnostics. Private/real captures must never enter Actions artifacts.

## Cloud Swift driver compatibility

Some Linux process-isolated workspaces cannot run the default Swift driver's
child-process accounting (`/proc/<pid>/stat` crash, even on unchanged source).
SwiftPM's integrated compiler driver works in that environment. When the
SwiftPM test runner hits the same process-monitoring issue, build the test
executable and run all XCTest cases directly:

```bash
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
```

Release mode runs the same assertions with production optimization, including
phone-scale cases. This changes compiler/test launch mechanics only; no
shipping code, assertions, or CI gates are weakened. A Swift Testing message
reporting zero tests is not proof this XCTest suite passed. Require the full
XCTest summary and exit status. Record the actual commands in the PR; normal
`verify-core.sh` and `gate.sh` remain the authoritative CI commands.
