# Task: Device Release verification and native failure diagnostics

Status: implemented; current-head CI and independent review gate integration.
Writer: Codex, branch `codex/device-release-readiness`.

## Goal

Verify an ordinary device-SDK Release build independently of fixture-enabled
simulator tests, and preserve useful evidence for intermittent Files failures.

## Why it matters

Current native CI passes, including post-merge run 35916314107 at `29d342de`.
Its Release UI binary deliberately includes `TRAKTION_UI_TESTING`; it does not
establish that an ordinary iOS Release product excludes synthetic bootstrap.
Issue #23 remains open after one blank system Files sheet and an unchanged
passing rerun. Existing failure artifacts omit stderr and simulator service logs.

## Scope and boundaries

- Build/check ordinary Release for generic iOS without credentials in required CI.
- Offer an explicit local signed build using actual configured team credentials;
  refuse missing or inconsistent signing settings. Do not enable provisioning
  updates, register identifiers, install on a device or upload a release.
- Validate effective settings and the built product, including fixture exclusion.
- Preserve bounded failure-only simulator logs before deleting the dedicated
  simulator; diagnostic failures must not replace the original verification status.
- Improve Files failure context without changing waits, assertions or retries.
- Update runbook, roadmap and task index with exact scope and remaining gates.

No production pixel/UI behavior, source assets, personal simulators, signing
credentials or app-icon geometry may change. An unsigned build is not a signed
device alpha or TestFlight readiness. Issue #23 is not fixed by adding diagnostics.

## Acceptance criteria

- [ ] Ordinary iOS Release compiles in a required CI job without test flags.
- [x] Settings/product validation rejects wrong platform/configuration, fixture
      bootstrap, metadata mismatch and invalid signed-build prerequisites.
- [x] Local signed mode preserves normal signing and never enables automatic
      provisioning/account changes or claims an installation.
- [x] Failure diagnostics are bounded, collected before simulator deletion and
      preserve the original failure even when collection fails or times out.
- [x] Native Files failure attachments identify the test and UTC timestamp.
- [ ] Meaningful validator/diagnostic failure-path tests and all CI gates pass.
- [ ] Independent review and documentation complete; no unrelated diff.

## Verification

Local Linux: `python3 -m unittest discover -s Tests/Repository -v` passed all
16 tests, including 8 new Release/diagnostic tests. The diagnostics tests execute
the shipped shell cleanup function with controlled commands and verify that
success, failure and diagnostic timeout outcomes preserve status and ordering;
the collector separately exercises real subprocess timeout and output-size limits.
Output caps are enforced while the host collector drains stdout/stderr pipes;
they do not depend on simulator-side processes inheriting host resource limits.
`bash -n scripts/verify-ios.sh` and `git diff --check` passed.

Mac CI must prove the actual ordinary device-SDK build and unchanged native test
inventory. A signed physical-device build is not possible without the actual
team/device and is not claimed. Real log collection depends on a native failure;
the collector reports missing/failed service-log commands explicitly. Exact
review, current-head CI and final integration evidence is recorded in this task's
PR to avoid recursive verification-only commits. Unchecked CI acceptance gates
above describe the pre-publication state and must pass before integration.

Independent read-only Release and diagnostics reviews found no blocking defect.
Review improvements were applied: retain allowlisted effective settings/Xcode
version, and enforce diagnostic output bounds in the collector rather than child
resource limits. Reviewers reproduced the repository tests; final review and CI
status remain in the PR.
