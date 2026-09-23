# Task: Bounded committed-result PNG export

Status: in progress — implementation and verification.
Writer: Codex, branch `codex/bounded-png-export`.

## Goal

Export the current committed reconstruction to PNG using the exact selected
original pixels, with bounded memory and explicit destination handling.

## Scope

- Define checked output admission and a bounded encoder contract before coding.
- Render validated original-source strips through the shipping Core; avoid
  retaining a second full-size edited composite.
- Export automatic or committed edited seams, preserving dimensions and pixels.
- Use real Files destination/name selection with create-only atomic publication
  and cancellation semantics. Any later overwrite mode needs a separately proven
  conditional replacement contract.
- Keep source images, saved projects and the in-memory edit history unchanged.
- Add accessible export/status/failure controls and reproducible diagnostics.

## Non-goals

PDF, JPEG/HEIC, split export, cloud sync, share extensions, new correction tools,
source deletion and physical-device distribution.

## Starting boundaries and decisions

- Export the committed `SeamEditingDocument.plan` and original captures.
  `NativeWorkspaceModel.result.image` remains the automatic composite, while
  result previews are downsampled; neither is edited-export pixel authority.
  Snapshot committed document/captures once. Match save's draft/rendering guard;
  the editing model's live plan can contain an uncommitted draft. Reset/cancel
  must keep the worker occupied until synchronous export work drains.
- Add an exact integer row/strip reader to `PlannedRasterRenderer`. Its existing
  preview/viewport APIs deliberately scale and enforce preview-size limits.
- Existing Apple and pure-Swift PNG encoders retain whole-image copies. Add a
  bounded streaming entry point behind `PNGCodec` in Vision, accepting rows via
  a closure so Vision does not depend on Core. The existing filter-0/stored-zlib
  format permits incremental checksums and bounded IDAT chunks in one zlib stream.
- Decide and document the export pixel limit before coding: the capture codec's
  16,777,216-pixel cap is smaller than Core's 67,108,864-pixel output cap. Do not
  silently widen capture-decoder admission to accommodate large exports.
- Check row, filtered-stream and encoded-size arithmetic, plus current-workspace
  and encoder working memory, before requesting rows or writing. Keep the
  create-only atomic publication and truthful cancellation/cleanup contract.
  Keep the publication source in private app storage, outside the selected
  folder; preserve the same-filesystem requirement and unsupported-location refusal.

## Acceptance criteria

- [x] Decoded exported pixels match independent automatic and edited-source oracles.
- [x] Exact and near-exact joins retain dimensions and selected source pixels.
- [x] A valid output beyond preview edge/pixel limits proves unsampled row export;
      instrumentation bounds requested rows and encoded chunks.
- [x] Representative output decodes through both Apple and pure-Swift PNG paths
      to the same RGBA oracle. Larger export verification has separate admission
      without widening production capture-decoder limits.
- [x] Draft/rendering exclusion, immutable committed snapshots and reset/cancel
      draining prevent mixed-state output or overlapping workers.
- [x] Large/invalid outputs and overflow refuse before exceeding resource limits.
- [x] Seam/strip/DEFLATE boundaries, partial final blocks, malformed rows,
      transparency and midstream writer failures have independent pixel/failure oracles.
- [x] Failed writes and precommit cancellation preserve existing destinations.
- [x] Postcommit status remains truthful and owned temporary cleanup is explicit.
- [ ] Real native Files export, cancellation and accessible controls are verified.
- [ ] Core/PNG/native gates, independent review, ADR and documentation pass.

## Verification record

2026-09-23 local Linux: Swift 6.0.3 release build with testable imports passed;
all 232 XCTest cases passed, including 11 export/streaming/model tests. Repository
policy and eight native-inventory guard tests passed. `git diff --check` passed.
The large streaming case decodes 4096 × 4097 pixels with an explicit test-only
allowance; production capture decoding remains capped at 16,777,216 pixels.

Exact commands: `swift build --build-tests --configuration release
--use-integrated-swift-driver -j 2 -Xswiftc -enable-testing`, followed by
`.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest`;
`bash scripts/check-repository.sh`; `python3 -m unittest discover -s Tests/Repository -v`.
Apple, native Files UI and current-head CI remain required before integration.
