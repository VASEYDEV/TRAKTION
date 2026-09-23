# TRAKTION Roadmap

## Status (2026-09-23)

| Milestone | State | Evidence |
| --- | --- | --- |
| 0 — Foundation | complete | PR #4, PR #5 |
| 1 — Exact static reconstruction | passed with measured platform evidence | corpus categories (0011), failure artifacts (0012), and gap regression repair (0014) landed; memory/throughput instrumentation (0013) verified on Linux and macOS in PR #16 |
| 2 — Sequence intelligence | in progress | exact ordering core (task 0007), tooling (task 0008), near-exact recovery (task 0009), repeated-chrome guard (0010), and bounded directional ambiguity guard (0014) landed; broader duplicates, missing-coverage evidence, and confidence workflows remain open |
| Native iOS app | simulator-verified editor, projects and PNG export | task 0019 / PR #19 established bounded inspection; PR #20 adds seam editing; task 0022 / PR #21 adds real Files save/open. The dependency stack is reconciled in task 0024. Task 0023 / PR #22 adds verified bounded committed PNG export. Physical-device verification remains separate |
| 3 — Non-destructive editor | in progress | bounded inspector (0019), seam adjustment (0020) and local project implementation (0022); further correction remains |
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

1. Bounded committed PNG export [0023](tasks/0023-bounded-png-export.md) is verified.
   Track further correction tools in a new packet; do not reopen completed stacks.
2. Establish a signed device build using the actual developer team, then verify
   real captures, resource behavior, Files save/reopen, accessibility and lifecycle
   behavior. Simulator checks already support developer testing of current features.
3. Finish production icon packaging, release configuration and distribution
   provisioning before a TestFlight build. Broader capture modes are later scope.

The [September 21 handoff](notes/2026-09-21-integration-and-testing.md) records
the #20 squash / #21 rebase-and-squash sequence, current test evidence, manual
testing checklist and repository-settings follow-ups. Sean explicitly authorized
integration and completed-branch deletion on September 21; earlier leave-open
instructions in historical session notes are superseded.

The original task-0014 gap regression remains preserved and repaired; broader
one-direction near-exact ambiguity is still an explicit limit (ADR-018).

Milestones 4–7 remain the product backlog; superseded PRs and completed task
packets are historical evidence, not parallel implementation plans.
