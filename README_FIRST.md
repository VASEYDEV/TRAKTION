# TRAKTION Foundation Kit

This package is the canonical starting point for agentic development of TRAKTION.

TRAKTION reconstructs overlapping screenshots, scroll captures, and related visual fragments into a continuous image while preserving source fidelity. The deterministic reconstruction engine owns pixel geometry, seam placement, validation, rendering, and export. An optional semantic visual reviewer may help classify ambiguous cases, but it never authors final pixels.

## Start here

1. Copy this package into the repository root.
2. Read `AGENTS.md`.
3. Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, and `docs/RECONSTRUCTION_SPEC.md`.
4. Create the initial repository structure described in `docs/ARCHITECTURE.md`.
5. Use `prompts/00_BOOTSTRAP_AGENT.md` as the first coding-agent assignment.
6. Do not add cloud-model integration until deterministic golden-corpus tests are passing.

## Canonical principles

- Deterministic vision owns final pixels.
- Source captures remain non-destructive by default.
- Missing coverage is reported, never silently fabricated.
- Core reconstruction must work offline.
- One writing agent owns a change at a time.
- Every material change is tied to acceptance criteria and tests.
- Golden fixtures and reproducible measurements outrank model confidence or prose.
- Runtime semantic review uses one provider at a time, selected behind an interface.
- The app should feel like a precision utility, not a chat application.

## Intended first milestone

Build a native Swift reconstruction laboratory that can ingest 2–10 equal-width PNG screenshots, reconstruct a known vertical sequence, detect exact or near-exact translational overlap, choose a seam, render a composite, emit diagnostics, and compare the output against a known source image.

No production AI integration is required for Milestone 1.
