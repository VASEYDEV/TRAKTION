# TRAKTION Roadmap

## Status (2026-09-17)

| Milestone | State | Evidence |
| --- | --- | --- |
| 0 — Foundation | complete | PR #4, PR #5 |
| 1 — Exact static reconstruction | passed with measured platform evidence | corpus categories (0011), failure artifacts (0012), and gap regression repair (0014) landed; memory/throughput instrumentation (0013) verified on Linux and macOS in PR #16 |
| 2 — Sequence intelligence | in progress | exact ordering core (task 0007), tooling (task 0008), near-exact recovery (task 0009), repeated-chrome guard (0010), and bounded directional ambiguity guard (0014) landed; broader duplicates, missing-coverage evidence, and confidence workflows remain open |
| Native iOS app | first reversible editor in review | task 0019 / PR #19 established import/reconstruction and bounded inspection; task 0020 adds seam apply/cancel/undo/redo; physical-device signing remains separate |
| 3 — Non-destructive editor | started | bounded inspector (0019), deliberate seam adjustment (0020); saved projects and further correction remain |
| 4–7 | not started | Product backlog below |

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

## Next execution order

1. Complete review and required CI for tasks [0020](tasks/0020-nondestructive-seam-adjustment.md)
   and [0021](tasks/0021-repository-health-and-product-handoff.md); leave the combined PR open.
2. Implement [0022](tasks/0022-local-project-persistence.md): versioned, local saved
   projects with original captures and validated edit plans.
3. Define bounded PNG export under its own packet, then further correction tools.
4. Verify physical-device signing and resource behavior with the actual developer
   team/device before distribution. Finish production icon packaging and visual polish.

The original task-0014 gap regression remains preserved and repaired; broader
one-direction near-exact ambiguity is still an explicit limit (ADR-018).

Milestones 4–7 remain the product backlog; superseded PRs and completed task
packets are historical evidence, not parallel implementation plans.
