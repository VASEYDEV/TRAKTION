# TRAKTION Agent Contract

This file is the canonical instruction source for all coding agents, reviewers, and automation working in this repository.

## Product invariant

TRAKTION reconstructs supplied visual evidence. It does not silently invent documentary content.

## Pixel-authority invariant

Deterministic image-processing code owns image normalization, overlap detection, registration, seam coordinates, compositing, continuity validation, tiling, rendering, export, and final pixel selection.

A semantic visual reviewer may classify ambiguity or recommend a non-destructive action, but its output must be validated by deterministic evidence before application.

## Runtime-model invariant

TRAKTION uses at most one active semantic reviewer provider in production. Provider selection is an implementation detail behind a protocol or interface. Do not build product behavior that requires multiple simultaneous model providers.

## Offline invariant

Core reconstruction, manual editing, project persistence, and export must function without network access or a model API.

## Source-integrity invariant

Original captures are non-destructive by default.

Never:
- overwrite source images,
- delete originals without explicit user action,
- fabricate missing text or pixels,
- silently bridge missing coverage,
- or convert a low-confidence reconstruction into a successful result without reporting uncertainty.

## Engineering rules

- Work from a tracked task with explicit acceptance criteria.
- One writing agent owns a branch or pull request at a time.
- Do not change unrelated files.
- Prefer small, reviewable changes over broad speculative rewrites.
- Add or update tests for every behavior change.
- Run the relevant test/build commands before declaring completion.
- Report exactly which commands were run and whether they passed.
- Do not weaken assertions merely to make a failing implementation pass.
- Do not commit generated placeholders, silently skipped tests, credentials, private captures, or API keys.
- Preserve deterministic behavior wherever practical.
- Prefer typed failures and explicit state over silent fallback behavior.
- Record architectural changes in an ADR.
- Do not introduce a dependency without documenting why the standard platform stack is insufficient.

## Architecture boundaries

Expected modules:
- `TraktionDomain`: stable value types and contracts.
- `TraktionCore`: sequence, registration orchestration, seam logic, continuity validation, reconstruction planning.
- `TraktionVision`: platform-specific OCR, registration, image operations, frame analysis.
- `TraktionUI`: canvas, sequence rail, joint inspector, editing interactions.
- `TraktionAI`: optional semantic reviewer protocol/adapters only.
- `TraktionLab`: diagnostic CLI/lab using shipping core code.
- `FixtureForge`: deterministic test-fixture generator.

Do not allow UI code to own reconstruction logic.
Do not allow model-provider SDK types to leak outside `TraktionAI`.
Do not let `TraktionAI` directly render or mutate full-resolution output pixels.

## Initial implementation constraints

Until explicitly expanded by a tracked task, Milestone 1 assumes vertical stitching only, 2–10 captures, identical pixel width, supplied sequence order, PNG input, translational alignment, static content, no web capture, no video reconstruction, and no semantic-reviewer calls.

## Definition of done

A change is not done until implementation is complete, acceptance tests pass, failure behavior is covered, relevant diagnostics are reproducible, documentation is updated when contracts changed, no unrelated diff remains, and the reviewer can independently reproduce the result.

## Review philosophy

Review evidence, not confidence.

For engine changes, prioritize false-safe failures, duplicated or missing rows/columns, nondeterminism, precision loss, memory amplification, and error masking.

For UI changes, prioritize source visibility, reversibility, accidental destructive actions, manual correction ergonomics, visual inspection at pixel scale, and accessibility.

## Security and privacy

- Never commit secrets.
- Treat screenshots and recordings as potentially sensitive.
- Minimize remote payloads.
- Do not upload the final long image by default.
- Use cropped diagnostic regions if semantic review is required.
- Keep source deletion as an explicit, post-export user action.
