<p align="center"><img src="assets/traktion-icon.svg" alt="TRAKTION amber T icon" width="112"></p>
<h1 align="center">TRAKTION</h1>
<p align="center"><strong>Deterministic reconstruction for overlapping screen captures.</strong></p>

TRAKTION is a local-first precision utility that reconstructs overlapping screenshots into a continuous image. Deterministic code owns geometry, seams, validation, and every exported pixel; missing or ambiguous evidence fails explicitly rather than being fabricated.

## Milestone 1

The current Swift foundation supports:

- 2–10 PNG captures in supplied vertical order;
- equal-width, static, integer-translation inputs;
- deterministic exact and configurable near-exact overlap scoring;
- hard seams rendered from original-resolution pixels;
- typed failures for invalid counts, dimensions, duplicates, ambiguity, and insufficient overlap;
- composite PNG, reconstruction manifest, and per-joint JSON diagnostics;
- an offline fixture generator and native SwiftUI application shell.

Automatic ordering, horizontal stitching, OCR, sticky-element recovery, video/web capture, and semantic-model integration are intentionally out of scope.

## Requirements

- Swift 6.0 or newer
- zlib development headers (`zlib1g-dev` on Ubuntu; provided by Apple SDKs on macOS)

## Build and test

```bash
swift build
swift test
bash scripts/gate.sh
```

## Diagnostic lab

```bash
swift run fixture-forge /tmp/traktion-fixture
swift run traktion-lab reconstruct \
  --axis vertical \
  --output /tmp/traktion-fixture/composite.png \
  /tmp/traktion-fixture/capture-001.png \
  /tmp/traktion-fixture/capture-002.png
cmp /tmp/traktion-fixture/source.png /tmp/traktion-fixture/composite.png
```

The lab writes `composite.png`, `composite.reconstruction.json`, and one `composite.joint-NNN.json` file per joint. Inputs are only read and are never overwritten.

## Architecture and policy

Start with [`AGENTS.md`](AGENTS.md), then read the [product](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [reconstruction](docs/RECONSTRUCTION_SPEC.md), and [evaluation](docs/EVALUATION.md) specifications. The accepted decisions in [`docs/adr`](docs/adr) define the architecture boundaries.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE). Copyright 2026 Sean Vasey.
