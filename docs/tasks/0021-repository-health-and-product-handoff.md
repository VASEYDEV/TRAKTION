# Task: Repository health and product handoff

Status: in progress — Codex owns the integration branch; independent audits complete.

## Goal
Reconcile all open PRs, branches and old checkouts; preserve useful work; leave
accurate product documentation, visuals, dependency/CI evidence and a clean open PR.

## Scope
- Compare GitHub PRs/branches and old local snapshots against main before deletion.
- Audit current main and historical failed workflow runs; retain causal evidence.
- Harden test-discovery checks without skipping cases or weakening assertions.
- Document shipping/framework/build dependencies and verification commands.
- Update README purpose, implemented/planned features, authentic screenshots and
  clear current/future capability labels, preserving the established logo geometry.
- Archive obsolete bootstrap instructions and update changelog/task handoff.
- Integrate independently owned task 0020 after its implementation and review.

## Acceptance criteria
- [ ] No useful implementation is discarded during cleanup.
- [ ] Current main and historical CI results are documented with exact run links.
- [ ] Missing/failed/duplicate/wrong-phase native tests cannot produce a green gate.
- [ ] README and visuals distinguish current behavior from planned capabilities.
- [ ] Dependency inventory, changelog, roadmap and active todo list agree.
- [ ] All changes are committed and pushed in an open PR; final-head CI passes.

Existing remote PRs may be squash-merged after review. New work remains in an
open PR as requested. Historical ADRs, task packets and measured reports remain
evidence rather than active work.
