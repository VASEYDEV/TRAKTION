# Task: Stack integration and testing handoff

Writer: Codex. Integration and final-current-head CI evidence: [PR #21](https://github.com/VASEYDEV/TRAKTION/pull/21).

## Goal

Preserve the verified seam-editing and persistence work on main, remove the
completed branches, and leave an accurate next task and testing handoff.

## Scope

- Audit all open PRs, remote branches, reviews, dependency ancestry and CI.
- Squash #20, rebase only #21's seven persistence commits onto that result,
  then squash #21 after its updated verification passes.
- Verify unchanged feature content with tree equality and `git range-diff`.
- Update status, roadmap and testing evidence.
- Resolve the late review finding that Unicode names can exceed the filesystem
  component limit: reject before I/O and prove the accepted boundary roundtrip.
- Delete completed remote branches only after preserving their work on main.

## Acceptance criteria

- [x] The branch inventory and #20 -> #21 dependency are verified.
- [x] Both original heads have all five successful CI jobs and no unresolved review threads.
- [x] #20 is squash-merged; the seven rebased #21 patches and full tree are unchanged.
- [x] Current features, next export task, release gaps and manual checks are documented.
- [x] Repository policy, native-result guard regressions and whitespace checks pass.
- [x] A regression reproduces the long-Unicode-name error, then proves typed
  refusal at 256/329 bytes and real save/reopen at the 255-byte boundary.

The remaining external completion gates are the current #21 head's five CI jobs,
its squash-merge record, main-tree equality and removal of both completed remote
branches. Their exact results belong in the PR's final integration section so
recording a new CI result does not recursively create another untested commit.

## Non-goals

No new feature, new dependency, changed assertion, distribution submission,
credentials, or branch-protection modification.

## Evidence

[Integration and testing note](../notes/2026-09-21-integration-and-testing.md).
