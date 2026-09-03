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
The PNG test explicitly skips when Apple ImageIO is unavailable.

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

Runs the standard 23-case corpus twice per case and exits non-zero on any false-safe,
false-warning, wrong-failure, or nondeterminism. The summary line reports the
EVALUATION.md ordering metrics (correct-sequence, duplicate-identification, and
missing-capture-detection counts) across the exact and near-exact ordering cases.

Successful completion ends with `GATE: PASS (repository · Swift build/tests · Apple PNG smoke)`.

## CI lanes

`.github/workflows/ci.yml` runs on every pull request and push to `main`:

- `verify / repository` on Ubuntu;
- `verify / core (Linux)` in the official Swift 6 Ubuntu image;
- `verify / Apple package and PNG smoke` on `macos-15`;
- `verification / required`, an `always()` aggregator that fails unless all three pass.

On Apple-smoke failure, CI retains only the generated synthetic fixture, composite,
manifest, and diagnostics. Private/real captures must never enter Actions artifacts.
