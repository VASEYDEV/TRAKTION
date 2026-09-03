# Task packets

One packet per tracked task, written from `templates/TASK_TEMPLATE.md`. A
change is not done until its packet's acceptance boxes are ticked from
command evidence (`AGENTS.md`, "Definition of done").

## Numbering rule

Take the next free number from this index. Numbers merged on `main` win over
numbers on unmerged branches: when two branches claim the same number, the
unmerged packet is renumbered on port (see task 0009 for the PR #8 example).
`docs/adr/ADR-NNN` numbers follow the same rule.

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
| [0008](0008-exact-ordering-tooling.md) | Exact-ordering tooling: Lab, smoke, evaluation ordering metrics | 2 | done | Claude | this branch |
| [0009](0009-near-exact-order-recovery.md) | Near-exact order recovery on the exact-ordering contract | 2 | planned | — | — |
| [0010](0010-repeated-chrome-guard.md) | Repeated-chrome fixture and identical-band guard | 2 / 4 | planned | — | — |
| [0011](0011-evaluation-corpus-categories.md) | Evaluation corpus visual categories | 1 follow-up | planned | — | — |
| [0012](0012-golden-failure-artifacts.md) | Golden-failure CI artifact bundle | 1 follow-up | planned | — | — |
| [0013](0013-peak-memory-instrumentation.md) | Peak-memory and throughput instrumentation | 1 follow-up | planned | — | — |

## Superseded packets and pull requests

- **PR #8** (`claude/traktion-dev-setup-f24qtq`, closed 2026-09-03 as
  superseded) carries packets numbered 0006 ("Automatic order recovery") and
  0007 ("Order-recovery tooling") and an ADR-014 written before the Codex
  audit merged its own 0006/0007/ADR-014. Those numbers belong to the merged
  packets above; the PR #8 tooling half landed as task 0008 (PR #10) and its
  engine half is task 0009, to be ported onto the merged contract. The branch
  is kept as the reference implementation for that port and may be deleted
  once 0009 lands.
- **PR #2** (`codex/create-initial-structure-for-traktion-project`, closed
  2026-08 unmerged) was an earlier foundation attempt superseded by PR #4
  (task 0001); its branch is gone.

Branches of merged pull requests are deleted after merge; `main` is the only
long-lived branch.
