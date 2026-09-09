# TRAKTION Roadmap

## Status (2026-09-09)

| Milestone | State | Evidence |
| --- | --- | --- |
| 0 — Foundation | complete | PR #4, PR #5 |
| 1 — Exact static reconstruction | passed with measured platform evidence | corpus categories (0011), failure artifacts (0012), and gap regression repair (0014) landed; memory/throughput instrumentation (0013) verified on Linux and macOS in PR #16 |
| 2 — Sequence intelligence | in progress | exact ordering core (task 0007), tooling (task 0008), near-exact recovery (task 0009), repeated-chrome guard (0010), and bounded directional ambiguity guard (0014) landed; broader duplicates, missing-coverage evidence, and confidence workflows remain open |
| Native iOS app | first workflow in verification | task 0017: PNG import, explicit supplied order, reconstruction preview and typed failures; scaffold verified in PR #16; physical-device signing remains separate |
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

## Next execution order

1. Finish verification and merge [task 0017](tasks/0017-native-png-reconstruction.md).
2. Implement [task 0019](tasks/0019-native-pixel-inspection.md): read-only
   pixel/joint inspection with bounded display memory and a real 1:1 view.
3. Add correction, undo/redo, project persistence, and export under separate
   Milestone 3 packets. Verify physical-device signing and resource behavior
   with the actual developer team/device when available.

The original task-0014 gap regression remains preserved and repaired; broader
one-direction near-exact ambiguity is still an explicit limit (ADR-018).

Milestones 4–7 remain the product backlog; superseded PRs and completed task
packets are historical evidence, not parallel implementation plans.
