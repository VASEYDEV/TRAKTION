# Task 0001: Deterministic Swift foundation

Status: In progress

Writer: Codex (`codex/m0-m1-deterministic-foundation`)

Reviewer: Independent reviewer required

Base: Foundation Kit PR branch (`claude/repo-init-traktion-9ybpqc`)

## Goal

Create the first runnable TRAKTION foundation and a bounded Milestone 1 vertical reconstruction slice using the canonical Foundation Kit.

## Why it matters

The repository currently specifies deterministic reconstruction but cannot build, generate controlled evidence, reconstruct a fixture, or prove pixel continuity.

## Current behavior

- Foundation Kit documentation is installed on the base branch.
- CI verifies repository hygiene only.
- No Swift package, reconstruction engine, PNG adapter, diagnostic tool, fixture generator, app shell, or golden test exists.

## Required behavior

1. Establish the architecture targets in `docs/ARCHITECTURE.md` with one root Swift package.
2. Keep RGBA pixel storage and reconstruction logic free of UI and provider SDK types.
3. Support 2–10 supplied-order, opaque, equal-width PNG captures on the vertical axis.
4. Detect unique exact or bounded near-exact bottom-to-top overlaps deterministically.
5. Fail closed on duplicate captures, incompatible widths, insufficient evidence, ambiguous exact placement, unsupported axis, invalid plan, or unsafe dimensions.
6. Compose once from original-resolution source rows using half-open source spans.
7. Emit a composite PNG, deterministic reconstruction JSON, and per-joint JSON/difference PNG diagnostics.
8. Generate a deterministic synthetic fixture independent of the production compositor.
9. Add a minimal SwiftUI preview shell without claiming an installable iOS application bundle.
10. Replace the docs-only CI gate with repository, cross-platform core, and Apple PNG smoke verification.

## Non-goals

- Automatic capture reordering
- OCR
- Horizontal reconstruction
- Sticky/fixed UI recovery
- Video or web capture
- Provider SDKs or production semantic-review calls
- Polished editor UI
- An Xcode iOS application project or signing pipeline
- Generative reconstruction of missing pixels

## Allowed paths

- `App/TRAKTION/`
- `Packages/`
- `Tools/`
- `Tests/`
- `.github/workflows/ci.yml`
- `.gitignore`
- `Package.swift`
- `scripts/`
- `README.md`, `CHANGELOG.md`, `FOUNDATION_CHECKLIST.md`
- `CLAUDE.md`
- `docs/adr/`, `docs/runbooks/`, `docs/notes/`, `docs/tasks/`

No license, brand asset, product-invariant, or model-policy change is authorized.

## Fixtures

- Exact two-capture overlap
- Exact three-capture sequence
- Repeated-looking rows with unique anchors
- Multiple exact periodic overlaps
- Unrelated captures
- Width mismatch
- Duplicate capture
- Larger deterministic performance fixture

## Acceptance tests

- Exact fixtures reconstruct to decoded RGBA equality with the untouched source canvas.
- Repeated execution returns an identical plan and output buffer.
- Periodic ambiguity produces `ambiguousOverlap` and no composite.
- Unrelated captures produce `insufficientOverlap` and no composite.
- Width mismatch and duplicate inputs produce their typed failures.
- Horizontal input produces `unsupportedAxis`.
- Apple PNG encode/decode preserves decoded RGBA pixels.
- The CLI smoke path generates captures, reconstructs, compares decoded pixels, and writes all diagnostics.

## Verification commands

```bash
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/gate.sh
```

`scripts/gate.sh` is the complete Apple gate. The current coding container has no Swift toolchain, so the change remains incomplete until the macOS CI execution passes.

## Required evidence

- Green repository, Linux core, and Apple verification jobs
- Synthetic source and composite decoded-pixel comparison
- Reconstruction manifest
- Per-joint diagnostic JSON and difference images
- Exact command results in the PR handoff
