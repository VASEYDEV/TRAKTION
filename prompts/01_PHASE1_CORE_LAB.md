# Prompt: Milestone 1 Reconstruction Core

Implement the first real deterministic reconstruction slice. Read `AGENTS.md` and the reconstruction/evaluation specs before changing code.

## Scope
Support 2–10 PNG captures, vertical axis, equal pixel width, supplied order, static content, and translation-only overlap.

## Required behavior
For each adjacent pair:
1. identify plausible bottom-to-top overlap,
2. score candidates deterministically,
3. choose the best valid overlap,
4. choose a seam,
5. compose from original-resolution pixels,
6. emit per-joint diagnostics,
7. return typed failures when no valid reconstruction exists.

## Output
`TraktionLab` must emit composite PNG, reconstruction JSON, and per-joint diagnostics.

## Tests
Add golden fixtures for exact two-image overlap, three-image sequence, repeated visual rows, insufficient overlap, width mismatch, and duplicate capture. For exact synthetic fixtures, compare reconstructed decoded pixels against known source truth.

## Non-goals
No OCR. No automatic reordering. No semantic reviewer. No sticky-header recovery. No video. No UI redesign.

Run all relevant tests and provide the handoff report.
