# 2026-08-31 — Swift foundation bootstrap (prompt 00)

Writer session executing `prompts/00_BOOTSTRAP_AGENT.md` on branch
`claude/traktion-dev-setup-f24qtq`.

## What landed

- Root `Package.swift` (Swift 6, tools-version 6.0) with targets mapped onto
  the documented layout; TraktionUI + app shell macOS-only (ADR-011).
- `TraktionDomain`: `ReconstructionAxis`, `CaptureAsset`, `CaptureSequence`,
  `JointConfidence`, typed `ReconstructionFailure`, `ReconstructionManifest`,
  `DeterministicJSON`.
- `TraktionCore`: `Milestone1Policy`, `SequenceValidator`, pure-Swift `SHA256`.
- `TraktionVision`: `PixelBuffer`, CRC-32/Adler-32, full RFC-1951 inflate +
  stored-block deflate, deterministic PNG codec.
- `TraktionAI`: `VisualReviewer` protocol + disabled/mock adapters mirroring
  `config/visual-review-decision.schema.json`. No provider SDK.
- Tools: `fixtureforge generate` (deterministic canvas → overlapping vertical
  captures + `fixture.json` ground truth) and `traktion-lab ingest` (load,
  validate Milestone 1 constraints, write `*.reconstruction.json`; failures
  are typed and still produce a manifest).
- Tests: 33 (unit, golden end-to-end incl. failure paths, performance smoke).
  Baseline fixture committed at `Tests/SyntheticFixtures/baseline-vertical-3`
  (seed 20260831); a golden test regenerates it and requires byte identity.
- Gate/CI: `scripts/gate.sh` now runs hygiene + `swift build` + `swift test`;
  CI runs the gate on Linux (swift:6.1-noble container) and build+test on
  macOS 15 (includes the SwiftUI shell).

## Test-vector provenance

Interop vectors in `Tests/Unit/TraktionVisionTests` (zlib streams, interop and
filtered PNGs) were generated once with CPython's `zlib` and embedded as
base64, so the decoder is proven against an independent DEFLATE implementation
without a test-time dependency.

## Deliberately out of scope (per prompt 00)

Overlap search/registration/seam/compose (prompt 01), the full FixtureForge
control set (prompt 02), app-shell UX (prompt 03), any semantic-reviewer
integration (prompt 09), horizontal stitching, video/web capture.
