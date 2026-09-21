# Task: Bounded committed-result PNG export

Status: queued — next implementation packet after verified task 0022.
Writer: assign one implementation owner at start.

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

- [ ] Decoded exported pixels match independent automatic and edited-source oracles.
- [ ] Exact and near-exact joins retain dimensions and selected source pixels.
- [ ] A valid output beyond preview edge/pixel limits proves unsampled row export;
      instrumentation bounds requested rows and encoded chunks.
- [ ] Representative output decodes through both Apple and pure-Swift PNG paths
      to the same RGBA oracle. Larger export verification has separate admission
      without widening production capture-decoder limits.
- [ ] Draft/rendering exclusion, immutable committed snapshots and reset/cancel
      draining prevent mixed-state output or overlapping workers.
- [ ] Large/invalid outputs and overflow refuse before exceeding resource limits.
- [ ] Seam/strip/DEFLATE boundaries, partial final blocks, malformed rows,
      transparency and midstream writer failures have independent pixel/failure oracles.
- [ ] Failed writes and precommit cancellation preserve existing destinations.
- [ ] Postcommit status remains truthful and owned temporary cleanup is explicit.
- [ ] Real native Files export, cancellation and accessible controls are verified.
- [ ] Core/PNG/native gates, independent review, ADR and documentation pass.
