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

Successful completion ends with `GATE: PASS (repository · Swift build/tests · Apple PNG smoke)`.

## CI lanes

`.github/workflows/ci.yml` runs on every pull request and push to `main`:

- `verify / repository` on Ubuntu;
- `verify / core (Linux)` in the official Swift 6 Ubuntu image;
- `verify / Apple package and PNG smoke` on `macos-15`;
- `verification / required`, an `always()` aggregator that fails unless all three pass.

On Apple-smoke failure, CI retains only the generated synthetic fixture, composite,
manifest, and diagnostics. Private/real captures must never enter Actions artifacts.
