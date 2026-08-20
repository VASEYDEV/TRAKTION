# Prompt: Bootstrap TRAKTION Foundation

You are the implementation agent for the initial TRAKTION repository bootstrap.

Read and obey `AGENTS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/RECONSTRUCTION_SPEC.md`, `docs/EVALUATION.md`, and all accepted ADRs under `docs/adr/`.

## Goal
Turn the base repository into a clean, buildable foundation for deterministic reconstruction work.

## Required work
1. Create the repository package/target structure described in `docs/ARCHITECTURE.md`.
2. Add the native application shell without polishing visual design.
3. Add `TraktionLab`.
4. Add `FixtureForge`.
5. Establish unit/golden/performance test directories.
6. Establish CI that builds and runs core tests on a clean checkout.
7. Create the initial domain types needed for Milestone 1 without speculative future abstractions.
8. Add one minimal end-to-end fixture proving the harness can load source assets and write diagnostics.

## Constraints
- No production semantic-reviewer integration.
- No provider SDK.
- No video/web capture.
- No horizontal stitching implementation.
- No broad design-system work.
- No generative image behavior.

## Deliverables
- buildable repository
- passing baseline tests
- documented build/test commands
- concise handoff using `prompts/08_PR_HANDOFF.md`

Do not declare completion unless a clean build and test run succeeds.
