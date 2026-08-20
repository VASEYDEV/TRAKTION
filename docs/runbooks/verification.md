# Verification runbook

Run these commands from the repository root on every material change:

```bash
swift format lint --recursive --strict Package.swift App Packages Tools Tests
swift test
swift build -c release
bash scripts/gate.sh
```

For an end-to-end reconstruction check:

```bash
rm -rf /tmp/traktion-fixture
swift run fixture-forge /tmp/traktion-fixture
swift run traktion-lab reconstruct --axis vertical --output /tmp/traktion-fixture/composite.png /tmp/traktion-fixture/capture-001.png /tmp/traktion-fixture/capture-002.png
cmp /tmp/traktion-fixture/source.png /tmp/traktion-fixture/composite.png
test -f /tmp/traktion-fixture/composite.reconstruction.json
test -f /tmp/traktion-fixture/composite.joint-001.json
```

`cmp` proves byte-identical PNG output for the deterministic exact fixture. Unit tests additionally compare decoded pixels, exercise three captures, and cover ambiguous repetition, insufficient overlap, width mismatch, and duplicate inputs.
