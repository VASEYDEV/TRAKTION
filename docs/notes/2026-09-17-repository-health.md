# Repository health and development handoff — 2026-09-17

## Starting state and branch reconciliation

Audited main: `c279264e9d7e552561a7e52ec5368df17e99af84`, tree
`455528541e30373b44fff9846363aed9eb3fc55c` ([PR #19](https://github.com/VASEYDEV/TRAKTION/pull/19)).
GitHub had **zero open PRs** and **only the main remote branch** at the audit.
There was no older remote branch requiring recovery or squash merge. Historical
superseded PRs #2, #8 and #14 remain closed evidence; their retained code was
already merged or deliberately superseded as recorded in the task index.

Two orphaned sibling checkouts were compared against reachable main history
before deletion. `TRAKTION-artifacts` had 151 files, all preserved as reachable
blobs. `TRAKTION-false-safe` had 144 files: 142 preserved blobs and two older
Golden test variants superseded by the merged diagnostic wrappers/helper access.
Their original fixtures and assertions remain on main. Neither checkout had a
live worktree registration, symlinks, or unique useful implementation. Removing
them recovered about 257 MB without deleting source history.

Root owns task 0021's integration branch. Task 0020 has a separate sole-writer
branch, reviewed before integration. New combined work remains in an open PR as
requested; do not squash-merge that new PR merely to make the branch list empty.

## Current main CI evidence

[Run 35163939876](https://github.com/VASEYDEV/TRAKTION/actions/runs/35163939876)
completed successfully with all five jobs: repository, Linux core, Apple package
and PNG, iOS simulator, and the required aggregator. Linux and Apple each ran
178 XCTest cases, the 45/45 evaluation corpus and both isolated performance
cases. Native verification ran six Debug cases in 259.609 seconds and the same
full-phone inspection case in Release in 80.984 seconds. The later Swift Testing
message saying zero tests is distinct from the completed XCTest suite.

The retained history contains 59 runs: 48 successful, eight failed, three
cancelled. This is a point-in-time audit, not an assertion that old failures were
rerun in place. Their fixes are demonstrated by later successful runs.

| Failed run(s) | Observed failure / cause | Resolution and evidence |
| --- | --- | --- |
| [35158214111](https://github.com/VASEYDEV/TRAKTION/actions/runs/35158214111) | Full-phone reconstruction still running after the unoptimized Debug wait | Same fixture/assertions now run optimized in Release; small interaction cases remain Debug; current main passes |
| [35159289876](https://github.com/VASEYDEV/TRAKTION/actions/runs/35159289876) | Reveal helper dragged inside the canvas and panned the pixels to the bottom | Scroll in the inspector margin; test actual canvas panning separately; current main passes |
| [35161855267](https://github.com/VASEYDEV/TRAKTION/actions/runs/35161855267) | XXXL reveal helper oscillated around the region picker | Bounded target-center scrolling; failure attachments exported without masking exit status; current main passes |
| [34270606092](https://github.com/VASEYDEV/TRAKTION/actions/runs/34270606092) | Apple phone-scale test took 379.826 seconds against the unchanged 240-second assertion | Full core suite uses production optimization; separate Debug build retained; inputs/assertions unchanged |
| [32527724530](https://github.com/VASEYDEV/TRAKTION/actions/runs/32527724530), [32528107171](https://github.com/VASEYDEV/TRAKTION/actions/runs/32528107171), [32528525515](https://github.com/VASEYDEV/TRAKTION/actions/runs/32528525515), [32528928242](https://github.com/VASEYDEV/TRAKTION/actions/runs/32528928242) | Zero jobs; historical workflow placed runner.temp in job-level env | Inferred workflow-validation cause: commit 0a201ec moved it to step env, and subsequent runs executed successfully. Original annotation is unavailable, so the cause is not presented as a recovered exact error |

No test assertion, source fixture, required lane, or product resource limit was
weakened to obtain passing CI. See the [dependency inventory](../DEPENDENCIES.md).

## Changes in task 0021

- Pin Actions to the exact commits already exercised on main; grant the workflow
  explicit read-only contents permission.
- Require every selected native test to have exactly one passing log record.
  Reject empty/partial results, failures, retries/duplicates and wrong-phase
  tests. This augments Xcode's process exit status. Source discovery currently
  covers `TRAKTIONLaunchTests`; extend it if another UI test class is added.
- Six Python regression cases pass. Independent review also removed each of the
  seven case records from actual main logs: each omission failed verification.
  Both unmodified main phase logs passed; aggregate-only success did not.
- Restrict the template-placeholder scan to text files so genuine compressed
  PNG screenshot bytes cannot trigger a false template error.
- Archive the completed foundation kit under `docs/archive/foundation-kit-v1`;
  retain its original manifest as provenance, not a current file inventory.
- Correct the missing task-0019 changelog/closure, stale policy references,
  README version claim, task disposition, and current/planned feature wording.
- Add unmodified, visually reviewed synthetic simulator screenshots with
  source-run provenance; preserve the established amber tread-T SVG masters.
  A separately labeled generated concept illustration communicates the product
  idea without claiming to be native UI or a pixel-accuracy example.

## Remaining administrative limitation

GitHub's About description still describes the unrelated AKTION/VIZION project.
The connector exposes no repository-metadata setter and the browser session is
signed out. Homepage is empty. No credentials or unrelated settings were touched.
Desired description:

> Precision screenshot reconstruction for iOS. Deterministic alignment,
> source-pixel inspection, and non-destructive editing.

The repository README now states the correct product purpose. This metadata
limitation does not block source development or the open PR.

## Integration verification

Final feature, review and CI evidence is recorded below after verification and in
the open PR. Earlier main results establish the baseline, not the new feature.

### Integrated local verification and cleanup

The integrated release build completed with Swift 6.0.3 using the documented
process-isolation workaround. The direct XCTest executable passed all **189
tests**, zero failures, in 41.155 seconds. The compiled release Lab evaluated the
standard corpus: **45/45 pass**, zero false-safe, false-warning, wrong-failure or
nondeterministic outcomes. Commands:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
.build/x86_64-unknown-linux-gnu/release/traktion-lab evaluate --output /tmp/traktion-editing-evaluation.json
python3 -m unittest discover -s Tests/Repository -v
bash scripts/check-repository.sh
bash -n scripts/verify-ios.sh
git diff --check
```

Task 0020's local implementation branch was integrated, then all 14 feature-file
blobs were compared against the integration commit. They matched exactly. Its
clean temporary worktree and branch were then deleted. Only main and the active
integration branch remain locally. [PR #20](https://github.com/VASEYDEV/TRAKTION/pull/20)
contains the work and remains open; no remote feature branch was silently merged.
Independent documentation review also verified screenshot provenance and active
relative links; the instructions now match the actual “Adjust this seam” label.

### Current PR native failure and repair

The first integrated [run 35220734815](https://github.com/VASEYDEV/TRAKTION/actions/runs/35220734815)
passed both core platforms but failed native verification. The expanded XXXL
scenario exceeded the unchanged per-case execution allowance; a later passing
line did not make the overall failed run acceptable. Its viewport and seam
accessibility scenarios are split with every assertion retained. See the
[seam note](2026-09-17-seam-editing.md) for the exact evidence and next-run result.

## Verified implementation closure

[Run 35222997795](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795) at `1daafd6d013eb4af92d26b2c4061b22e8cb1e1e4` passed all five jobs. Linux and Apple each
ran 189 XCTest cases, PNG smoke, 45/45 evaluations and both isolated performance
cases. Native verification passed **nine Debug cases** in 312.551 seconds
and the unchanged **one full-phone Release case** in 61.950 seconds.
Both source-inventory guards passed; there were no failed/retried/timed-out case
records. The focused XXXL scenarios and early-exit reveal helper resolve the
first run's test-structure failure without increasing limits or dropping checks.

Applied-history, landscape-draft and XXXL seam-control attachments from the
successful run were actually inspected. The modified state/history, draft
boundary and accessible controls are visible. An unmodified editor screenshot
is retained in the README gallery with exact provenance.

Tasks 0020/0021 are complete in [PR #20](https://github.com/VASEYDEV/TRAKTION/pull/20),
which remains open as requested. Task 0022 is the next implementation packet.
This records the verified implementation run; current PR checks remain the
merge gate after documentation/artwork changes. Final-head CI is recorded in
the PR rather than creating another documentation-only verification cycle.
