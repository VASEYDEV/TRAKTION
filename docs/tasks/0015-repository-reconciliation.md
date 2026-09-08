# Task: Repository reconciliation and development handoff

Status: complete; authenticated remote branch deletion remains an access follow-up

## Goal
Make the active plan agree with merged history and the verified app boundary.

## Current behavior
The task index still says "this branch" for merged work, README cites an old
23-case corpus, and PR #14 repeats the already-merged PR #13 implementation.
Three remote branches are complete or superseded. The iOS app target remains absent.

## Required behavior
- Record merged PR references, remove superseded work from the active queue,
  and preserve historical decisions and original regression evidence.
- Close superseded PR #14 and delete eligible branches where access permits.
- State test evidence and native-app work still required without claiming
  an installable build from a successful SwiftPM run.

## Allowed scope
README, CHANGELOG, roadmap, task index, verification runbook, session notes.

## Non-goals
Account permissions, license, brand, CI gate weakening, and source history rewriting.

## Acceptance criteria
- [x] Active queue and completed work match reviewed code and PR history.
- [x] Completed/superseded branches are removed or explicitly recorded as blocked.
- [x] Repository check and diff whitespace check pass.
- [x] Verification and native-app limitations are documented.

## Build / test commands
```sh
bash scripts/check-repository.sh
git diff --check
```

## Writer
Codex (continuation branch).

## Reviewer
Independent code review plus owner-visible PR diff.
