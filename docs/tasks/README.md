# Task packets

One packet per tracked task, written from `templates/TASK_TEMPLATE.md`. A
change is not done until its packet's acceptance boxes are ticked from
command evidence (`AGENTS.md`, "Definition of done").

## Numbering rule

Take the next free number from this index. Numbers merged on `main` win over
numbers on unmerged branches: when two branches claim the same number, the
unmerged packet is renumbered on port (see task 0009 for the PR #8 example).
`docs/adr/ADR-NNN` numbers follow the same rule.

## Active work

Completed packets below are historical evidence, not queued work. Continue from
current `main`; never restart a superseded branch.

1. **[0019](0019-native-pixel-inspection.md):** read-only pixel/joint inspection
   with bounded display memory. Editing, persistence, and export follow in
   separate packets; physical-device signing requires the actual team/device.

## Index

| Task | Title | Milestone | Status | Writer | Landed |
| --- | --- | --- | --- | --- | --- |
| [0001](0001-deterministic-foundation.md) | Deterministic Swift foundation | 0–1 | done | Codex | PR #4 |
| [0002](0002-lab-failure-manifest.md) | Typed failure manifests for `traktion-lab` | 1 | done | Claude | PR #6 |
| [0003](0003-fixtureforge-control-set.md) | FixtureForge control set and adversarial goldens | 1 | done | Claude | PR #6 |
| [0004](0004-evaluation-harness.md) | Evaluation harness with metrics report | 1 | done | Claude | PR #7 |
| [0005](0005-adaptive-candidate-refinement.md) | Adaptive early-exit candidate verification | 1 | done | Claude | PR #7 |
| [0006](0006-milestone-1-audit.md) | Milestone 1 evidence audit | 1 | done | Codex | PR #9 |
| [0007](0007-exact-sequence-ordering.md) | Fail-closed exact sequence ordering (core API) | 2 | done | Codex | PR #9 |
| [0008](0008-exact-ordering-tooling.md) | Exact-ordering tooling: Lab, smoke, evaluation ordering metrics | 2 | done | Claude | PR #10 |
| [0009](0009-near-exact-order-recovery.md) | Near-exact order recovery on the exact-ordering contract | 2 | done | Claude | PR #12 |
| [0010](0010-repeated-chrome-guard.md) | Repeated-chrome fixture and identical-band guard | 2 / 4 | done | Codex | PR #13 |
| [0011](0011-evaluation-corpus-categories.md) | Evaluation corpus visual categories | 1 follow-up | done | Codex | PR #13 |
| [0012](0012-golden-failure-artifacts.md) | Golden-failure CI artifact bundle | 1 follow-up | done | Codex | PR #15 |
| [0013](0013-peak-memory-instrumentation.md) | Peak-memory and throughput instrumentation | 1 follow-up | done | Codex | PR #16 |
| [0014](0014-monospaced-missing-coverage-false-safe.md) | Monospaced missing-coverage false-safe and directional proof | 1 follow-up | done with documented limits | Codex | PR #15 |
| [0015](0015-repository-reconciliation.md) | Repository reconciliation and development handoff | cross-milestone | done | Codex | PR #15 |
| [0016](0016-native-ios-scaffold.md) | Native iOS target and required simulator gate | native foundation | done | Codex | PR #16 |
| [0017](0017-native-png-reconstruction.md) | Native PNG import and supplied-order reconstruction | first native workflow | done | Codex | PR #18 |
| [0018](0018-project-pr-template.md) | Project-specific pull request template | workflow | done | Codex | PR #17 |
| [0019](0019-native-pixel-inspection.md) | Native pixel and joint inspection | native inspection | queued | assign at start | — |

## Superseded packets and pull requests

- **PR #14** (`codex/check-development-state-and-resume`, closed 2026-09-08):
  the engine guard and visual-category work already landed in PR #13. The
  remaining alternate fixture implementation conflicts with main and carries
  stale task documentation. It is superseded; preserve reference head
  `b5d090899cb7773524db3e948a293062a3c04a2c` through the closed PR.

- **PR #8** (`claude/traktion-dev-setup-f24qtq`, closed 2026-09-03 as
  superseded) carries packets numbered 0006 ("Automatic order recovery") and
  0007 ("Order-recovery tooling") and an ADR-014 written before the Codex
  audit merged its own 0006/0007/ADR-014. Those numbers belong to the merged
  packets above; the PR #8 tooling half landed as task 0008 (PR #10) and its
  engine half landed as task 0009, ported onto the merged contract. The
  archived author session left one further reconciliation commit on the
  branch (renumbering to 0008/0009/ADR-015, never verified or opened as a
  PR); the branch is now fully superseded and can be deleted.
- **PR #2** (`codex/create-initial-structure-for-traktion-project`, closed
  2026-08 unmerged) was an earlier foundation attempt superseded by PR #4
  (task 0001); its branch is gone.

Policy: delete branches after their work is merged or verified as superseded;
`main` is the only long-lived branch. The earlier access-blocked cleanup was
verified resolved during PR #16; the continuation note preserves its history.

## Native app handoff

The SwiftPM `TRAKTION` executable remains a macOS preview path. Task 0016 verified
the Xcode iOS target, shared scheme, simulator installation/UI tests, and
developer-owned signing configuration. Its CI evidence is distinct from
core/CLI tests. Task 0017 adds real PNG import, explicit supplied-order reconstruction, and
result/failure presentation. Pixel inspection, editor, project persistence, and
export still require implementation. A simulator
pass does not establish physical-device signing or App Store readiness.
