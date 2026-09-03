# Task: Milestone 1 evidence audit and Milestone 2 entry criteria

## Goal
Produce a reproducible, evidence-based Milestone 1 audit and turn every material
gap into an explicit entry criterion for the next development task.

## Why it matters
The deterministic foundation, fixture control set, evaluation harness, and
adaptive registration work are merged, but completion must be decided from the
implementation and current verification output rather than commit summaries.

## Current behavior
Tasks 0001–0005 are marked complete. The README still describes a stacked draft
pull request, and there is no consolidated milestone audit recording verified
capabilities, evidence gaps, or the boundary for sequence-intelligence work.

## Required behavior
1. Record the audit sections required by `prompts/07_MILESTONE_AUDIT.md`.
2. Re-run the portable repository, Swift, PNG smoke, and evaluation gates.
3. Inspect the implementation and tests behind tasks 0004 and 0005, with
   particular attention to false-safe behavior and bounded registration.
4. Update the README status to point at the audit and current evaluation command.
5. Identify explicit prerequisites for beginning Milestone 2 without changing
   the Milestone 1 supplied-order runtime contract.

## Non-goals
- Automatic capture ordering or overlap-graph implementation.
- UI/editor behavior.
- Changes to reconstruction thresholds, budgets, or pixel selection.
- Changes to the canonical agent contract.

## Allowed scope
- `README.md`
- `CHANGELOG.md`
- `docs/audits/`
- `docs/tasks/`
- `docs/notes/`

## Forbidden changes
- `Packages/`, `Tools/`, `Tests/`, `App/`, CI, and gate scripts.
- `AGENTS.md` and architecture ADRs.

## Inputs / fixtures
- Standard in-process evaluation corpus from task 0004.
- Existing golden, integration, performance-shape, and unit tests.

## Acceptance criteria
- [x] Audit records completed and partial capabilities, golden status,
      false-safe findings, performance/memory concerns, privacy/security,
      architecture drift, blocking debt, and a milestone recommendation.
- [x] Every finding distinguishes observed evidence from recommendation.
- [x] README no longer refers to the completed work as a stacked draft PR.
- [x] Milestone 2 entry criteria preserve fail-closed and supplied-order behavior
      until a separately reviewed task expands the contract.
- [x] Tests and portable gates pass deterministically.
- [x] No unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
swift build
```

## Required evidence
- command output
- `/tmp/evaluation-report.json`
- this audit report

## Writer
Codex (branch `work`)

## Reviewer
Independent reviewer required before merge.
