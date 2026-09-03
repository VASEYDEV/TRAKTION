# Task: Automatic order recovery (Milestone 2, sequence intelligence core)

## Goal
The engine recovers the documentary order of an unordered capture set by
building the pairwise overlap graph and requiring a unique acceptable
full-coverage order, with the same fail-closed guarantees as supplied-order
reconstruction. This task is the tracked expansion of the Milestone 1
"supplied sequence order" constraint (AGENTS.md, "Initial implementation
constraints") into Milestone 2 per docs/ROADMAP.md.

## Why it matters
Milestone 2 ("Sequence intelligence") requires the pairwise overlap graph,
automatic order recovery, and typed detection of reversed, misplaced, and
disconnected captures. RECONSTRUCTION_SPEC.md §Ordering reserves the typed
states `ambiguousOrder` and `missingCoverage` for exactly this.

## Current behavior
`ReconstructionEngine.reconstruct` consumes captures strictly in supplied
order; a reversed or misplaced capture surfaces as `insufficientOverlap`.
There is no ordering API and no `ambiguousOrder`/`missingCoverage` failure.

## Required behavior
1. `ReconstructionEngine.recoverOrder(_ captures: [CaptureAsset])` validates
   exactly as `reconstruct` does (count 2–10, resource bounds, byte-identical
   duplicates, equal widths), probes every directed pair with the existing
   registration machinery (same thresholds, budgets, and the ADR-012 /
   ADR-013 verification pipeline), and solves for directed paths that cover
   every capture:
   - exactly one acceptable full-coverage order → `RecoveredOrder` with
     per-junction evidence (accepted candidate + confidence);
   - more than one → `ambiguousOrder` (deterministic sample of candidate
     orders plus the total count);
   - none → `missingCoverage` (the deterministic longest acceptable chain
     and the captures it leaves uncovered).
2. Pair probes reuse one implementation: `register` is refactored into an
   outcome-returning probe plus a thin throwing wrapper; supplied-order
   behavior stays byte-identical. Pair-level `ambiguousOverlap` contributes
   no edge; any budget exhaustion during graph construction fails the whole
   recovery with `resourceLimitExceeded` (never a partial graph decision).
3. `ReconstructionEngine.reconstructRecoveringOrder(_:axis:)` composes
   recovery with the existing supplied-order `reconstruct`, so the final
   plan and pixels are always produced (and re-verified) by the reviewed
   Milestone 1 path.
4. `TraktionDomain` gains `RecoveredOrder`, `RecoveredEdge`, and failure
   cases `ambiguousOrder` / `missingCoverage` with stable wire codes
   (additive; existing codes unchanged).
5. Determinism: identical inputs yield identical recovered orders, evidence,
   and failure payloads (fixed pair iteration order, deterministic path
   enumeration and tie-breaks).
6. ADR-015 records the unique-acceptable-order rule and the solver design.

## Non-goals
- OCR-continuation or geometry-prior edge scoring (later evidence sources).
- Tolerant duplicate handling (byte-identical captures remain the typed
  `duplicateCapture` failure; near-duplicate policy is a later task).
- Horizontal-axis ordering; subpixel or affine registration.
- CLI/fixture/evaluation surface (task 0009).

## Allowed scope
- `Packages/TraktionDomain/Sources/TraktionDomain/ReconstructionModels.swift`
- `Packages/TraktionCore/Sources/TraktionCore/`
- `Tests/Golden/`, `Tests/Unit/`
- `docs/adr/ADR-015-*.md`, `CHANGELOG.md`, `docs/notes/`

## Forbidden changes
- `Packages/TraktionVision/`, `Packages/TraktionAI/`, `Packages/TraktionUI/`,
  tools, scripts, CI. No change to supplied-order observable behavior.

## Inputs / fixtures
Generated in-process from `FixtureControlGenerator` outputs and hand-built
rasters; nothing committed.

## Acceptance criteria
- [x] Shuffled 3–5 capture sets (including fully reversed) recover the
      ground-truth order and reconstruct pixel-identical to source.
- [x] A symmetric two-capture set acceptable in both directions fails with
      `ambiguousOrder` listing both orders.
- [x] Removing a middle capture from a shuffled set fails with
      `missingCoverage` naming the uncovered captures.
- [x] Pair-level periodic ambiguity never silently converts into an edge:
      the periodic golden content still refuses (`missingCoverage` or
      `ambiguousOrder`, never a composite).
- [x] Tiny explicit budgets during graph construction fail closed with
      `resourceLimitExceeded`.
- [x] Supplied-order suite passes unchanged (register refactor is
      behavior-identical); two-run determinism holds for recovery results
      and failure payloads.
- [x] ADR-015 committed.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
```

## Writer
Claude (branch `claude/traktion-dev-setup-f24qtq`)

## Reviewer
Independent reviewer required before merge (engine change: prioritize
false-safe review per AGENTS.md).
