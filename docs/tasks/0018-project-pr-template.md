# Task: Project-specific pull request template

Status: done — documentation-only change, independently reviewed.

## Goal
Give every new GitHub PR a concise, evidence-oriented TRAKTION handoff.

## Why it matters
The existing template omits platform verification boundaries, resource evidence,
and recurring reconstruction-review lessons. PR authors supply these inconsistently.

## Scope reviewed
Reviewed main at `9427debc958895c19a355d39209d46eecfdcb389`, `AGENTS.md`, the
product/architecture/roadmap, task 0017, verification runbooks, and recent PRs.
The product is a native Swift/SwiftUI reconstruction and non-destructive editing
utility with a shared deterministic core, Lab, and FixtureForge. The current
build has vertical PNG reconstruction, sequence recovery, evaluation/performance
evidence, and a read-only iOS shell. Native import is next; editing, persistence,
fixed-element recovery, recording, optional semantic review, and broader export
remain staged work rather than completed features.

PR [#7](https://github.com/VASEYDEV/TRAKTION/pull/7) demonstrates before/after
regression and budget evidence. PR [#15](https://github.com/VASEYDEV/TRAKTION/pull/15)
preserves a previously obscured gap fixture; its review requires both outcomes
for nondeterminism artifacts. PR [#16](https://github.com/VASEYDEV/TRAKTION/pull/16)
separates process RSS, host tests, simulator evidence, and unverified device work.

## Required behavior and allowed scope
- Expand `.github/pull_request_template.md` with task/ownership, changes,
  verification, conditional reconstruction/resources and native/editor evidence,
  contract/privacy impact, and reviewer focus.
- Keep `templates/PR_TEMPLATE.md` identical and link the PR handoff prompt.
- Record this documentation task in the task index.

## Non-goals and forbidden changes
No app behavior, architecture, dependencies, fixtures, tests, CI gates, branch
policy, or queued feature work changes. Do not hardcode current corpus counts
or imply simulator checks establish device/distribution readiness.

## Acceptance criteria
- [x] GitHub's existing default template path contains the tailored template.
- [x] Portable template matches; the handoff prompt identifies the canonical path.
- [x] Conditional sections can be omitted for small/documentation-only changes.
- [x] Independent review confirms alignment with repo contracts and PR evidence.
- [x] Repository policy, whitespace, and template equality checks pass.

## Verification
- `bash scripts/check-repository.sh` — PASS, including the staged task packet.
- `git diff --check` and `git diff --cached --check` — PASS.
- `cmp .github/pull_request_template.md templates/PR_TEMPLATE.md` — PASS.
- Independent read-only review repeated policy, whitespace, and equality checks;
  approved with no blockers.

Runtime builds/tests were not run locally for this documentation-only change.

## Writer and reviewer
Writer: Codex. Reviewer: independent read-only scope/template review agent.
