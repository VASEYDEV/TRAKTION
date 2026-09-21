# Integration and testing handoff — 2026-09-21

## Outcome and scope

TRAKTION has an experimental native iOS workflow for importing 2–10 opaque,
equal-width PNGs, confirming their vertical order, reconstructing static content,
inspecting original pixels/joints, adjusting proven seams with undo/redo, and
saving/reopening local projects. There are no external Swift package dependencies
and no runtime network/model calls.

This is a tested simulator build, not a signed device release. PNG export is the
next implementation task. A complete end-to-end tester workflow and TestFlight
distribution still require the work below; the wider product roadmap is not
feature-complete.

## Branch and PR reconciliation

The initial remote inventory contained exactly `main`,
`codex/repository-health-and-editing` (#20), and
`codex/local-project-persistence` (#21). There were no other open PRs or issues.
Both local worktrees were clean. Main was `c279264`; #20 contained five commits,
and #21 contained seven additional commits on top of #20. They were a dependency
stack, not competing implementations. All six review threads in #21 were resolved;
#20 had no review threads or blocking review submissions.

Sean explicitly authorized merging, dependency correction and completed-branch
deletion in this session. This supersedes the older leave-open instruction and
the approval rejection recorded in historical notes.

1. Squash #20 at verified head `7861e97fc70a1b547439be1e2f42e4ab8665ed88`.
   The resulting main commit is `39cd70be3758acfa330646d8855dee1c3afd13f8`;
   its tree exactly equals the verified #20 tree.
2. Rebase only the seven commits after that original #20 head onto new main.
   The rebase completed without conflicts. `git range-diff` reports all seven
   patches unchanged; the resulting `9260bef` tree exactly equals original #21
   head `f3559a7e3a82f43cc72840b4d7229603ef903284` (tree
   `fcc04a6d6b1ebbf6e6b6f91178fbfc38e9e026f1`).
3. Add only the current integration/testing documentation, retarget #21 to main,
   publish after confirming the remote still has its expected original head, and require all five
   jobs on that current head before its squash merge.
4. Verify the merged main tree equals the tested #21 tree. Delete both completed
   remote branches only after this comparison; keep main as the sole long-lived
   branch. Preserve the merged PRs, ADRs, fixtures and historical evidence.

The final [PR #21 integration section](https://github.com/VASEYDEV/TRAKTION/pull/21)
records current-head/main CI, the merge SHA and observed cleanup results.

## Verified evidence before integration

| Revision | Evidence |
| --- | --- |
| #20 `7861e97` | [Run 35224910195](https://github.com/VASEYDEV/TRAKTION/actions/runs/35224910195): all five jobs succeeded; 189 Linux/Apple XCTest cases, 45/45 evaluation cases per platform, 9 Debug and 1 Release native cases |
| #21 `f3559a7` | [Run 35571352579](https://github.com/VASEYDEV/TRAKTION/actions/runs/35571352579): all five jobs succeeded; 220 Linux / 219 Apple XCTest cases, 45/45 evaluation cases per platform and isolated performance cases |
| Native #21 log inspected in this session | 13 Debug cases in 606.120 seconds and 1 full-phone Release case in 63.732 seconds; both inventory guards passed. Edited Files roundtrip: 104.217 seconds; name-collision/relaunch/reopen: 65.518 seconds |
| Local reconciliation checks | Swift 6.0.3 release build (16.72 seconds) and all 220 XCTest cases (23.523 seconds) passed; repository policy, eight native-log guard regressions, shell syntax, whitespace and unchanged-tree/range comparisons passed |

The one-test Linux/Apple difference is the real Linux cross-filesystem refusal
regression. The required workflow aggregates repository policy, Linux core,
Apple package/PNG, and native simulator lanes. Historical failures were fixed
before the successful runs: Files alert accessibility lookup, unsafe save races,
UI-owned restoration policy, I/O error classification, and native timeout/restart
detection. No timeout budget or assertion was relaxed for this integration.

## Testing readiness and remaining work

| Stage | Current position | Remaining requirement |
| --- | --- | --- |
| Developer simulator testing | Available, covered by native CI | Follow the iOS runbook; test the supported scope and record defects |
| Signed iPhone alpha | Not yet demonstrated | Actual Apple team, bundle/signing configuration, device install and launch |
| End-to-end tester workflow | Import/edit/save/reopen available | Task 0023: bounded PNG export of the committed result with independent pixel verification |
| Device qualification | Simulator/portable evidence only | Real screenshots, device memory/latency, interruptions, Files/provider behavior and VoiceOver |
| TestFlight distribution | Not ready | Production icon, release configuration/versioning, signed archive, provisioning and App Store Connect setup |
| Broader product | Backlog | Additional correction tools, general sticky-element recovery, recording/web/horizontal capture and broader formats |

Start implementation from main with [task 0023](../tasks/0023-bounded-png-export.md).
The existing bounded preview is not an export source: exported pixels must come
from the committed Core plan and original captures. The task specifies streaming
rows, checked limits, create-only publication, cancellation and real Files tests.

## First manual testing pass

1. Import two through ten representative same-width, opaque PNG screenshots;
   reorder/remove captures, confirm order and reconstruct. Check every join against
   the originals, including text, tables, dark UI and long captures.
2. Exercise 1:1 inspection, pan/zoom, original-source selection, portrait/landscape
   and large text. Check VoiceOver focus and speech on an actual device.
3. Adjust a seam, cancel a draft, apply, undo/redo, close/reopen the inspector and
   confirm the originals remain unchanged.
4. Save to On My iPhone, terminate/relaunch and reopen. Confirm order, seam pixels
   and modified state; fresh undo history after reopening is intentional.
5. Try a duplicate name, corrupt project, interrupted/cancelled operation and a
   large replacement workspace. Confirm existing files and the current workspace
   survive refusals. Record device model, OS, build revision and reproducible steps.
6. After task 0023, compare exported PNG dimensions and full-resolution pixels
   with the committed result; verify failures/cancellation do not overwrite files.

Use synthetic or consented captures in shared diagnostics. Third-party Files
providers may sync independently and may not support the same-filesystem hard
links required for safe project saves. External Files tap-to-launch association
and general provider compatibility are not implemented/established.

## Repository-settings follow-ups

The active ruleset `Default` (ID 22592746) targets literal `refs/heads/Default`,
not the default branch `main`. The branch API reports main unprotected. Its
current rules also do not require the CI aggregate. This audit manually requires
all five successful jobs; it does not change repository access controls. Correct
the target and configure `verification / required` in a dedicated settings change.

The prior health audit also recorded unrelated AKTION/VIZION About text. Correct
that metadata when repository-settings access is available; the suggested text
is in the September 17 health note. These settings issues are distinct from app
implementation and simulator verification.
