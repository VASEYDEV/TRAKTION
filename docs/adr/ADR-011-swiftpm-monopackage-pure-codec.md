# ADR-011: Single SwiftPM Package and Pure-Swift Asset Codec for the Foundation

Status: Accepted

## Context

The bootstrap (prompts/00_BOOTSTRAP_AGENT.md) requires the repository layout of
docs/ARCHITECTURE.md, CI that builds and tests a clean checkout, and a
deterministic end-to-end fixture path. Development and CI must also run on
Linux, where SwiftUI, ImageIO, and CryptoKit do not exist.

## Decision

1. **One SwiftPM package at the repository root** declares every module as a
   target with an explicit path following the documented layout
   (`Packages/*`, `Tools/*`, `Tests/*`, `App/*`), rather than one package per
   directory. Module boundaries are enforced by targets; a single
   `swift build` / `swift test` covers the repository.
2. **`TraktionUI` and the app shell are declared only on macOS hosts** (a
   `#if os(macOS)` block in `Package.swift`). Domain, core, vision, AI
   contract, tools, and all engine tests build and run on Linux and macOS.
3. **Tools are split into a `Kit` library target plus a thin CLI executable**
   (`FixtureForgeKit`/`fixtureforge`, `TraktionLabKit`/`traktion-lab`) so tests
   exercise exactly the shipping code.
4. **PNG encode/decode, CRC-32/Adler-32, DEFLATE, and SHA-256 are implemented
   in pure Swift** inside `TraktionVision`/`TraktionCore`. Decode handles real
   PNGs (full inflate, all five filters, 8-bit gray/RGB/RGBA); encode writes
   8-bit RGBA with stored-block zlib. Unsupported formats fail typed.

## Rationale

- Platform codecs (ImageIO) and hashes (CryptoKit) are Apple-only and are not
  byte-stable guarantees across platforms; a pure-Swift codec makes fixture
  and output bytes identical everywhere, which golden comparisons (ADR-002,
  ADR-005) depend on. The dependency policy in AGENTS.md rules out external
  packages without documented insufficiency; none is needed.
- Stored-block compression trades file size for simplicity and determinism.
  Fixture assets are small; real entropy coding can be added later behind the
  same API without changing any caller.

## Consequences

- `swift build` and `swift test` from the root are the canonical clean-build
  and test commands; `scripts/gate.sh` runs hygiene checks plus both.
- Apple-framework-backed implementations (vImage, Vision OCR, Metal) can later
  live in `TraktionVision` behind the same types, with the pure-Swift paths as
  the cross-platform reference implementation.
- Committed fixture PNGs are larger than max-compression PNGs; acceptable at
  baseline-corpus scale. Revisit if the corpus grows large.
