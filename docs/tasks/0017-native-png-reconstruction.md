# Task: Native PNG import and supplied-order reconstruction

Status: queued — next implementation task after PR #16.

## Goal
Import a user's PNG captures in the native app, confirm their top-to-bottom
order, and show the real reconstruction or its typed failure.

## Why it matters
The verified engine currently runs through the Lab. The native shell needs
one usable reconstruction workflow before an editor or project format.

## Current behavior
The native app is a read-only shell. The shared PNG codec and supplied-order
vertical engine exist. The engine is synchronous and does not cooperatively
cancel; its aggregate raster limit is checked after input decoding.

## Required behavior
- Import one batch of 2–10 PNGs from Files. Show numbered thumbnails, names,
  and dimensions; provide simple move/remove controls and require explicit
  confirmation of top-to-bottom order before reconstruction.
- Validate actual file content, static PNG format, opacity, matching widths,
  and overflow-safe per-image/aggregate dimensions. Preflight resource limits
  before allocating full rasters, then decode sequentially. Account for
  retained workspace data when admitting a replacement batch.
- Import atomically: invalid or cancelled input preserves the previous
  workspace. Read external files with coordinated, balanced security-scoped
  access; never overwrite or delete originals. Any owned temporary copies
  must be cleaned without touching source URLs.
- Reuse the existing codec and `ReconstructionEngine` with `.vertical` and
  supplied order. Keep stable capture identities when changing list order.
- Publish state on `MainActor`; perform file reading, decoding, and engine
  work on one non-main worker. Admit only one operation at a time. A cancelled
  request may discard its result but must keep the worker occupied until the
  synchronous operation actually returns; request identities reject stale
  completion. Do not imply cancellation immediately frees engine memory.
- Show truthful reading/reconstructing states, then the actual composite,
  dimensions, and joint confidence, or the existing typed failure mapped to
  visible capture names. Preserve supplied captures for inspection. Avoid
  additional full-resolution copies for thumbnails and result presentation.

## Non-goals
Automatic ordering, Photos import/transcoding, editing, undo/redo, persistence,
export, semantic review, production artwork, and device distribution.

## Allowed scope
- `Packages/TraktionUI`: workspace state, importer coordination, and views.
- `Packages/TraktionVision`: narrowly scoped PNG metadata/resource preflight
  and platform file/image adapters where the existing codec is insufficient.
- App/package target linkage and relevant unit, integration, and UI tests.
- This packet, the task index, roadmap, runbooks, and an ADR for the workflow.

## Forbidden changes
Core reconstruction algorithms/thresholds, fabricated output, silent capture
omission, first-frame extraction from animation, destructive source actions,
new shipping dependencies without justification, or unrelated milestones.

## Inputs / fixtures
Use genuine synthetic source truth and PNG captures from FixtureForge,
including supplied-order success, duplicate, missing-coverage, and directional
ambiguity cases. Keep private screenshots out of CI and diagnostic artifacts.

## Acceptance criteria
- [ ] Real synthetic PNG import through the production service reconstructs
      exact source pixels; user-confirmed order reaches the engine unchanged.
- [ ] Invalid count, corrupt/non-PNG content, transparency, animation, width
      mismatch, and excessive dimensions fail atomically with useful errors.
- [ ] Source hashes are unchanged after success, failure, cancellation, reset,
      and replacement; temporary-file cleanup affects owned copies only.
- [ ] Duplicate, missing-coverage, and directional-ambiguity fixtures preserve
      their typed failures and never display a successful composite.
- [ ] Worker tests prove one active operation, non-main execution, cancelled
      result suppression, stale-completion rejection, and bounded admission.
- [ ] Simulator tests exercise the real importer service with synthetic file
      URLs, order confirmation, success, failure, and reset in portrait,
      landscape, and larger text. Real picker presentation/cancellation is
      checked separately from deterministic service injection.
- [ ] Existing repository, portable, Apple PNG, and native simulator gates
      pass; independent review confirms source integrity and memory ownership.
- [ ] No unrelated diff or claim of physical-device readiness.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/gate.sh       # macOS
bash scripts/verify-ios.sh # macOS with Xcode and an installed simulator
git diff --check
```

## Required evidence
Full test results, source-pixel and source-hash comparisons, typed-failure
diagnostics, worker lifecycle assertions, and simulator screenshots/results.
Record actual import/reconstruction memory behavior before choosing a mobile
resource policy; process peaks from task 0013 do not establish device limits.

## Writer and reviewer
Assign one implementation owner when starting; require independent review of
file access, concurrency, memory admission, typed failures, and UI behavior.
