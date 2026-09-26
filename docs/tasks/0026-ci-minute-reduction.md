# Task: CI Apple-lane minute reduction

## Goal
Cut GitHub Actions spend on the TRAKTION `ci` workflow by running the three macOS lanes only when Apple-relevant paths change, and never on push to `main`.

## Why it matters
September 2026 billing: TRAKTION consumed $49.31 of $78.33 total Actions spend (63%) and exhausted the 3,000 included minutes. macOS 3-core runners cost $0.062/min (10.3x Linux); the ~20-minute iOS simulator job is ~$1.24 of the ~$1.46 each full run costs, and it ran 78 times in 26 days — once per PR synchronize plus again on merge to `main`.

## Current behavior
`.github/workflows/ci.yml` runs all six jobs on every `pull_request` synchronize and every push to `main`. A merged PR therefore runs the full macOS lanes twice for identical changes.

## Required behavior
- A new `changes` job (ubuntu-24.04) detects Apple-relevant path changes via `dorny/paths-filter` v4.0.3, pinned by SHA.
- The `apple`, `ios-release`, and `ios` jobs run on `workflow_dispatch` always, on `pull_request` only when Apple paths changed, and never on push to `main`.
- `verification / required` keeps its exact name (required by branch ruleset 22592746) and passes when Apple lanes are skipped; it still fails them on failure or cancellation.
- Filter failure is fail-safe: Apple lanes run (status quo) instead of being skipped.

## Non-goals
- Shortening `scripts/verify-ios.sh`; its Debug-plus-Release structure is deliberate test evidence.
- Changing what any lane verifies, or renaming the required check.

## Dependency note
`dorny/paths-filter` (MIT, SHA-pinned) is introduced because GitHub's native `paths` filters are workflow-level only: they would skip the Linux lanes as well, and splitting the workflow into two files would break the branch ruleset's required `verification / required` check on PRs that do not touch Apple paths. Per-job gating requires changed-file detection, which the platform does not provide natively.

## Allowed scope
- `.github/workflows/ci.yml`
- `docs/tasks/0026-ci-minute-reduction.md`
- `docs/tasks/README.md` (index row only)
- `CHANGELOG.md` (`[Unreleased]` entry only)

## Forbidden changes
- Any change to lane scripts, app code, package code, or test assertions.
- Renaming the `verification / required` check.
- New workflow files.

## Inputs / fixtures
- Billing evidence: September 2026 cycle, TRAKTION $49.31 of $78.33 Actions spend.

## Acceptance criteria
- [ ] Push to `main` runs `repository` and `core-linux` only; Apple lanes report skipped; `verification / required` is green.
- [ ] A PR touching only `docs/` skips the Apple lanes; a PR touching `App/` runs them.
- [ ] `dorny/paths-filter` is SHA-pinned with the justification recorded above.
- [ ] No unrelated diff.

## Build / test commands
```sh
# No local build applies to a workflow change; the workflow run itself is the test.
# The landing PR run exercises the filter positively (ci.yml is an Apple path);
# the post-merge push run exercises the skip path.
```

## Required evidence
- The PR run: Apple lanes ran, `verification / required` green.
- The post-merge push run: Apple lanes skipped, `verification / required` green.

## Writer
Muse

## Reviewer
Sean Vasey
