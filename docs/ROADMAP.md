# TRAKTION Roadmap

## Status (2026-09-03)

| Milestone | State | Evidence |
| --- | --- | --- |
| 0 — Foundation | complete | PR #4, PR #5 |
| 1 — Exact static reconstruction | passed with follow-ups | `docs/audits/2026-09-03-milestone-1.md`; follow-ups are tasks 0011–0013 |
| 2 — Sequence intelligence | in progress | exact ordering core (task 0007), tooling (task 0008), and near-exact recovery (task 0009) landed; repeated-chrome guard (task 0010), duplicates, missing coverage, confidence states open |
| 3–7 | not started | — |

Task packets and their status live in `docs/tasks/README.md`.

## Milestone 0 — Foundation
Repository structure, shared agent contract, architecture docs, CI, TraktionLab skeleton, FixtureForge skeleton, baseline golden fixtures.

## Milestone 1 — Exact static reconstruction
Vertical input, equal-width PNG captures, supplied order, exact/near-exact translational overlap, seam selection, PNG composition, golden validation, typed failures.

## Milestone 2 — Sequence intelligence
Pairwise overlap graph, automatic order recovery, duplicates, missing coverage, confidence states.

## Milestone 3 — Non-destructive editor
Joint inspector, ghost/difference/edge views, pixel loupe, nudge/magnetic snap, internal cut, trim, undo/redo, project persistence.

## Milestone 4 — Fixed viewport elements
Sticky header/footer detection, scrollbar detection, floating control masks, Viewport Lock, alternate-source recovery.

## Milestone 5 — Scroll recording
Frame extraction, scroll trajectory, redundant-frame removal, reversal detection, transient-region handling, source-frame selection.

## Milestone 6 — Optional semantic reviewer
Provider-neutral protocol, disabled/mock implementation, one production adapter, minimized diagnostic payload, structured output, deterministic validation of recommendations.

## Milestone 7 — Broader capture/export
Horizontal reconstruction, web capture, share extension, PDF, JPEG/HEIC, split export, target-size controls, long-image optimization.
