# Local project continuation — 2026-09-21

## Starting state and ownership

PR #20 remained open at `7861e97fc70a1b547439be1e2f42e4ab8665ed88`, with all five
checks green and no unresolved review findings. Main remained `c279264`.
Automatic approval review rejected the requested squash merge because the earlier
instruction left #20 open. No base/default-branch mutation occurred. Development
continues in [PR #21](https://github.com/VASEYDEV/TRAKTION/pull/21), targeting
`codex/repository-health-and-editing`; future merging needs explicit authorization.

The implementation owner worked alone on `codex/local-project-persistence`.
Root owns integration/documentation. Independent design and code review covered
framing, evidence validation, resource admission and atomic/cancellation behavior.
[ADR-024](../adr/ADR-024-local-project-container.md) was written before implementation.

## Implemented behavior

Projects embed exact PNG bytes retained during import, capture identity/order,
automatic evidence and committed seam metadata. Opening reruns the shipping
engine, rejects unreproducible evidence and restores validated seams directly.
Undo/redo starts empty after reopening. No archive-wide buffer, external package,
network/model call or fabricated pixel is introduced.

Saving uses a user-selected Files folder/name. Every save creates a new file via
an atomic no-clobber link. Existing projects, unrelated files, directories and
symlinks are preserved; a collision requires another name. Cancellation shares
the publication lock.
Review found silently ignored temp cleanup failures and a dangling-symlink edge
case; both were fixed with regression evidence. Cleanup failure stays visible
even after cancellation/reset and distinguishes a project already saved.

[GitHub review](https://github.com/VASEYDEV/TRAKTION/pull/21#discussion_r4059426916)
also found a check/rename race in the initial explicit replacement path. Independent
review confirmed that file coordination does not exclude uncoordinated writers.
The replacement API and UI were removed; the final atomic link itself refuses an
intervening destination. Regression tests preserve genuine projects, renamed PNGs,
directory contents and regular/dangling symlinks. A native collision scenario
checks both current-workspace preservation and the unchanged saved project after
an empty relaunch.

A subsequent architecture review moved the reopen policy behind Core's
`ProjectRestorer`: reconstruction, exact saved-evidence comparison and committed
seam validation belong to one reusable Core contract. The file adapter retains
framing, admission, decoding and I/O. Direct Core regressions independently forge
saved evidence and committed geometry instead of relying only on file round trips.

Another review identified a second race in the original sibling staging path:
an uncoordinated selected-folder writer could substitute the source pathname
before `link`. Saving now stages in an exclusively created private app directory
outside the destination folder and removes only that owned directory. Atomic
no-clobber publication remains mandatory; cross-filesystem locations fail closed.
This protects against selected-folder writers, not privileged access to private
app storage. The regression attempts source substitution through the selected
folder and verifies exact original bytes plus preservation of unrelated files.

The final error-classification review found that broad open-error handling labeled
Foundation file/staging failures as corruption. Explicit JSON/PNG validation
failures remain `invalidContainer`; known file-access failures and remaining
Foundation/OS errors become `fileAccess`. Resource, cancellation, cleanup and Core
evidence failures preserve their categories. Existing codec `decodeFailed` remains
undecodable content because its backends do not expose every underlying I/O cause.
The format and private save publication contract are unchanged.

Private synthetic captures moved from Documents to Application Support when
Documents was exposed to Files. The simulator script alone seeds a corrupt
synthetic project for the real picker refusal case.

## Local verification

Swift 6.0.3 on Ubuntu 24.04:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
.build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
python3 -m unittest discover -s Tests/Repository -v
bash -n scripts/verify-ios.sh
git diff --check
```

Release build and **204 XCTest cases** passed, zero failures, 21.681 seconds.
After exclusive temporary-file creation was added, the release build and all
11 project-store tests passed again in 0.121 seconds. Six Python guard tests,
shell syntax, the plist/UTI contract and whitespace checks passed.

After the create-only review fix, the release build passed in 26.88 seconds;
12 project-store tests passed in 0.126 seconds and four model tests in 0.206 seconds.
Independent review found no remaining blocker. The complete release XCTest
binary then passed all **205 cases**, zero failures, in **21.396 seconds**.
The expanded native inventory is 13 Debug plus one Release case; full CI was
still pending at this point.

After extracting Core's restoration contract, the release build passed in
20.88 seconds and the full portable suite passed **211 XCTest cases**, zero
failures, in **21.693 seconds**. Six direct Core regressions add independent
evidence/edited-pixel acceptance coverage; existing file/model tests still pass.
Independent review found no remaining boundary issue. The commands above are
unchanged; current-head CI remains the publication gate.

After private source staging, the release build passed in 18.05 seconds and all
**214 Linux XCTest cases** passed, zero failures, in **23.259 seconds**. Two new
portable regressions verify substitution resistance/private ownership, plus one
Linux-only test exercises real cross-filesystem refusal using `/dev/shm`.
Apple inventory is **213**; there are no silently skipped cases.

After the error-classification fix, the release build passed in 18.91 seconds;
all **218 Linux XCTest cases** passed, zero failures, in **23.362 seconds**.
Apple inventory is **217**. Four added regressions distinguish real missing-file,
staging and decoder-source access failures from bad JSON/PNG CRC, with cleanup
and original-file preservation assertions. Independent review found no blocker.

The implementation was published as `a4a8ce8e0e6af6d41ab71570d71a46783ab6155d`,
with tree `ac2a198ae7816ba967c08ca45f9a44083a39836c` verified identical to the
local commit. [First CI run](https://github.com/VASEYDEV/TRAKTION/actions/runs/35563606874)
passed repository/Linux/Apple lanes: 204 tests on each Swift platform, 45/45
evaluations, both isolated performance cases, PNG smoke and six guard regressions.
Native Debug ran 12 cases in 397.913 seconds; two save cases failed with five
assertions before reaching Files because the alert's text field did not expose
the SwiftUI `project.name` identifier. Release was not reached.

The retained accessibility tree and an inspected recording frame show the actual
focused field with placeholder `Project name`. The first selector fix selected
that field inside the Save project alert and attempted to dismiss the observed
first-use system keyboard introduction through Continue. Dialog trees/screenshots
were retained. Assertions, time limits and required lanes were preserved.

The create-only fix was published as `24c8a06110144590379ab597765972ef19e99d40`;
the alert selector fix as `8c87c65f5734422695d9a5bb7ed711e57ad29f39`, tree
`490166e8ba0c203d9933527bc20df53451cc7266`, matching the local tree. GitHub did not
immediately queue a synchronize run after this push, so PR #21 was closed/reopened
to request the existing workflow. The delayed synchronize event subsequently
started [run 35564839626](https://github.com/VASEYDEV/TRAKTION/actions/runs/35564839626),
superseding the brief reopen run 35564834718 through existing concurrency rules.
PR #21 remains open with the same base and commits.

Run 35564839626 passed repository/Linux/Apple: 205 tests on each Swift platform,
45/45 evaluations, both isolated performance cases, PNG smoke and six guards.
Native ran all 13 Debug cases in 521.349 seconds, with two failures; Release was
not reached. The complete collision/save/relaunch/reopen case passed in 72.729
seconds, proving the actual create-only Files flow in that scenario.

The first failure log shows XCTest treating Save project as an interruption while
tapping Continue outside the alert, then cancelling the alert itself. Tests now
interact only with the focused alert field and explicitly assert the typed name.
The second failure's inspected screenshot/tree shows a real folder sheet with
Back/More/Open; an accessibility-only Cancel proxy overlaps More. The cancellation
test now uses the visible sheet's downward dismiss gesture, then requires both
the picker and Open control to disappear before checking unchanged workspace,
status and errors. No injected URL, bypassed assertion or longer case timeout was
introduced. Updated native verification remains required.

The collision refusal, reopened saved-project status and XXXL controls screenshots
from the individually passing scenarios were also inspected. They confirm visible
new-name guidance and local-project controls; this partial visual evidence does
not turn the overall failed run into an acceptance pass.

Core extraction, corrected ADR, native interaction fixes and action runtime pins
were published as `2ba0bad8178e409322fbaba2f6a35fa51d6139a1`, with tree
`9177e635f0ac4cc40aa55bde26a430d05dd4a7b5` verified identical to the local commit.
[Run 35566279530](https://github.com/VASEYDEV/TRAKTION/actions/runs/35566279530)
is the next complete verification attempt. Its repository/Linux/Apple jobs passed:
211 XCTest cases on each Swift platform, 45/45 evaluations, both isolated
performance cases, PNG smoke and six guard regressions. The completed logs use
the new action pins without Node 20 deprecation warnings; both expected evaluation
artifacts were retained. Native executed 13 Debug cases in 531.548 seconds with
two failures; Release was not reached. Naming and the real edited save/relaunch/
reopen path worked, but a test incorrectly expected output row 136 in the label
that actually displays automatic overlap row 24. The inspected screenshot shows
automatic overlap 24, committed output/overlap 137/25, Exact confidence and empty
history. The corrected test checks the initial output/overlap 136/24 and exact
automatic-label equality after reopening.

The other failure was the XXXL open picker's Cancel identifier lookup, despite
the inspected screenshot/tree showing a visible Cancel control. It now shares
the already passing modal-dismiss gesture with folder cancellation and requires
the picker, header and Open control to disappear. Save-cancel/corrupt preservation
passed in 41.611 seconds; collision/save/relaunch/reopen passed in 55.254 seconds.
These are partial results, not overall native acceptance.

Private staging and the final native coordinate/dismissal corrections were
published as `69ece5f7b3ae96bd620c8d31991c52d61a80780d`, tree
`77b1c9065a2aae58198e21096dc1c7a9594b65a2`, again matching the local tree.
[Run 35567629142](https://github.com/VASEYDEV/TRAKTION/actions/runs/35567629142)
passed repository/Linux/Apple: 214 Linux and 213 Apple XCTest cases, PNG smoke,
45/45 evaluations, both isolated performance cases per platform and six guards.
Native failed: the edited roundtrip exceeded its unchanged 120-second allowance,
then printed a passing record at 132.443 seconds. The following collision test
failed while terminating the app; Xcode restarted and retried it. Later passing
records do not establish acceptance. Release was not reached. The source-publication
review was resolved with regression evidence; all four review threads then present
were resolved.

The timing log shows expensive diagnostic captures, including an 18.44-second
gap around the redundant intermediate saved-state screenshot. Successful dialog
trees/screenshots now become failure-only, and that intermediate capture is
removed. Every assertion, real picker interaction, timeout and final reopened
screenshot remains. The source inventory is unchanged at 13 Debug plus one
Release case. Two new parser regressions reject timeout/restart markers even
alongside a complete passing inventory; all eight guard tests pass. Independent
review confirmed the preserved coverage and found no blocker.

These verification repairs and the open-error classification fix were published
as `5821eac039b9e182bc465572e32090aaf40c08e7`, tree
`72205e2a9ca803cfb55194ab112ea3ab57f394e1`, verified identical to the local tree.
The fifth review thread was resolved with its four I/O regressions and 218-case
local result. [Run 35569321865](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865)
is the fresh complete verification attempt. Its repository/Linux/Apple jobs passed:
218 Linux and 217 Apple XCTest cases, PNG smoke, 45/45 evaluations, both isolated
performance cases on each platform and all eight guard regressions.

Earlier run 35564839626 reported deprecated Node 20 action pins and an upcoming
Ubuntu image migration. Independent source/runner review supports checkout and
upload-artifact v7.0.1 on Node 24, pinned by full release SHA, and explicit Ubuntu
24.04 labels. The final workflow keeps every required lane, assertion, permission
and artifact path. The pins have since executed successfully and retained artifacts
in the completed portable jobs; final-head verification still includes all lanes.
Details are in the [dependency inventory](../DEPENDENCIES.md).

A final length-classification review found zero manifest length was reported as
resource exhaustion, incorrectly advising a reset/smaller project. The lower and
upper guards are now separate: nonpositive manifest/source byte lengths are
invalid framing, while above-cap declarations remain resource failures. Two
regressions prove predecode refusal and successful inclusive-cap manifests/PNG
sources with unchanged bytes and reconstructed pixels. Independent review found
no blocker. The release build passed in **19.69 seconds** and the complete local
suite passed **220 Linux cases**, zero failures, in **22.620 seconds**; Apple
inventory is **219**. Commands remain the same; final-head CI belongs in PR #21.

## Resource and platform limits

Ten 1170 × 2532 captures reserve **249,397,888 owned raster bytes**; tests verify
the exact remaining 19,037,568-byte old-workspace allowance and rejection above
it before decoding. The separate encoded cap is 128 MiB across old and incoming
workspaces. These are admission bounds, not RSS or physical-device guarantees.

Use local On My iPhone storage for offline operation. Third-party Files providers
can synchronize independently and may refuse the atomic filesystem operations.
External Files tap-to-launch association, format migrations, physical-device
signing and export remain outside task 0022. Task 0023 queues bounded PNG export.

## Verification closure

[Run 35569321865](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865)
at `5821eac039b9e182bc465572e32090aaf40c08e7` passed all five jobs on attempt 1.
Native passed **13 Debug cases in 688.860 seconds** and the **one full-phone
Release case in 70.589 seconds**. Both inventory guards passed, with no failed,
duplicate, skipped, timed-out or restarted case. The edited Files roundtrip took
107.253 seconds and the collision roundtrip 101.110 seconds, within the unchanged
120-second allowance. The observed environment was iPhone SE (3rd generation),
iOS 26.2 and Xcode 16.4 (16F6); the Apple package job used Swift 6.1.2.

The downloaded native ZIP (artifact `10626196524`, 9,257,995 bytes) matched
SHA-256 `e2299098ac802ff765bf36fdbb6f64d5ef42f0617c9eeee1709258c21f55780b`.
Actual reopened-project, committed-seam, XXXL controls and corrupt-project refusal
screenshots were inspected. Two unchanged project captures are retained with
[provenance](../../assets/screenshots/README.md). The seam capture shows automatic
overlap 24, committed output/overlap 137/25, Exact evidence and fresh history.

Task 0022 implementation is verified; task 0023 is the next development packet.
The later two length-classification regressions pass in the 220-case local suite.
Final pushed-head CI, including these fixes and documentation/artwork, is tracked
in [PR #21](https://github.com/VASEYDEV/TRAKTION/pull/21) rather than creating a
recursive documentation-only verification cycle. Both PRs remain open and main
remains unchanged because automatic approval review blocked the earlier merge.
