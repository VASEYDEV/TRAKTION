# ADR-011: Apple ImageIO Codec Boundary with a Pure-Swift Fallback

Status: Accepted

## Context

The deterministic foundation (PR #4) isolated PNG I/O behind `PNGCodec` in
`TraktionVision`, implemented with Apple ImageIO/CoreGraphics. That kept the
engine platform-neutral but made every real end-to-end path (decode →
reconstruct → encode → compare) require macOS: the Linux CI lane could build
and unit-test the engine, never exercise it against files. The independent
review of PR #4 flagged the absence of an ADR for this boundary.

## Decision

1. `PNGCodec` remains the single codec seam, with the Apple ImageIO
   implementation unchanged on Darwin platforms.
2. On non-Apple platforms the same `PNGCodec` API is now backed by a
   pure-Swift codec (`PurePNGCodec` + RFC 1951/1950 inflate and stored-block
   deflate, no dependencies) under the identical contract: opaque input only
   (an alpha sample below 255 or a tRNS chunk is `unsupportedTransparency`),
   the same error cases, and the same pixel-count limit. `PNGCodec.isAvailable`
   is true everywhere.
3. Golden authority stays **decoded RGBA equality**, never encoded PNG bytes —
   ImageIO's output bytes are not guaranteed stable across OS releases, and the
   two backends compress differently by design.
4. Cross-backend parity is pinned by tests: `Tests/Integration` decodes
   independently encoded vectors on both backends, round-trips each backend's
   output through the other, and asserts identical typed failures for
   transparency and file-contract errors. `scripts/smoke.sh` runs the full
   fixture → reconstruct → compare → diagnostics path on every host.

## Consequences

- Linux CI now runs true end-to-end verification; a codec regression on either
  backend fails a lane.
- Decode support on non-Apple hosts is deliberately narrow (8-bit gray/RGB/RGBA,
  non-interlaced); exotic PNGs fail typed rather than approximately.
- The pure codec's stored-block output is larger than ImageIO's; nothing
  compares or commits those bytes.
- If byte-identical outputs across platforms ever become a requirement
  (ADR-002 determinism at the byte level), the recorded option is switching
  Darwin to `PurePNGCodec` behind the same seam — a one-file change gated by
  the parity tests.
