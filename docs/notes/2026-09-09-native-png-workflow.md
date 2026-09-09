# Native PNG workflow: implementation and verification

Date: 2026-09-09
Task: [0017](../tasks/0017-native-png-reconstruction.md)
Implementation commit: `7110d833374a5b64d2154008ab4a5840f0118800`

## Implemented
The native app imports actual PNG files atomically, shows numbered thumbnails,
preserves stable IDs during move/remove, requires order confirmation, and runs
the supplied-order vertical engine off the main thread. It displays the actual
result as a bounded preview, dimensions and joint confidence, or typed failures
mapped to capture names. Failed/cancelled replacement keeps the old workspace.
Cancel/reset suppress old image publication and keep the worker occupied until
it drains. Cleanup errors stay visible after cancellation/reset.

[ADR-021](../adr/ADR-021-native-png-workspace.md) records ownership, preflight,
codec inflation bounds, cancellation and resource contracts. No registration
algorithm/threshold, shipping dependency, original image, or private fixture
changed. Inspection, editing, persistence, export and physical-device signing
remain separate. [Task 0019](../tasks/0019-native-pixel-inspection.md) is next.

## Executed verification
Linux x86_64, Swift 6.0.3, optimized build:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
TRAKTION_GOLDEN_ARTIFACTS=/tmp/traktion-native-golden-evidence \
  .build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
.build/x86_64-unknown-linux-gnu/release/traktion-lab evaluate \
  --output /tmp/traktion-native-evaluation.json
bash scripts/check-repository.sh
bash -n scripts/verify-ios.sh
git diff --check
```

The build and all **165 XCTest tests passed**, zero failures (29.888 seconds).
The release CLI passed **45/45 cases**, with zero false-safe, false-warning,
wrong-failure and nondeterministic verdicts. Existing order-recovery capability
remains 4/5 correct-sequence fixtures; that documented capability boundary is
unchanged and is distinct from the acceptable-result gate.

New coverage comprises 15 importer integration tests, eight inflation-bound
regressions and 13 workspace/pipeline tests. Tests compare genuine source pixels
and original encoded bytes, including duplicate, missing-middle and directional
ambiguity refusals. Controlled workers prove non-main execution, one admitted
operation, drain-before-reentry, reset/cancel suppression, retained-workspace
reservation, preview admission and visible cleanup failure.

Independent service, codec, UI and workspace reviews found no remaining
blockers. The final reviewer reran both workspace suites: 13 passed, zero failures.
The cloud toolchain intermittently crashed in libdispatch process accounting
(`/proc/<thread>/stat`) before a build completed. An unchanged-source retry
completed successfully; the direct release XCTest runner executed every test.
This is why these commands substitute for the local SwiftPM test launcher.
The unchanged normal CI gates remain required.

## Fresh-process input/reconstruction memory
Fixtures were generated in separate processes before measurement: 1170×2532
pixels per capture, 700-row overlaps, seed 51, supplied order, three and ten
captures. Source dimensions are 1170×6196 and 1170×19020 respectively. The long
source exceeds the per-PNG codec limit, so the generator writes only individual
capture PNGs and genuine source fingerprint/geometry metadata. It does not
raise codec limits or write a truncated source image.

The measured driver invokes the production `NativeWorkspaceWorker` importer
and engine and the exact internal `NativeRasterPreview` sampler synchronously.
It reserves thumbnail memory, retains captures/previews/result, verifies output
source fingerprint, dimensions and every expected overlap, and checks all
capture SHA-256 values in a separate process before/after. Thirteen original
PNGs were unchanged. No generated images or binaries are committed.

| Fresh Linux worker process | Three captures | Ten captures |
| --- | ---: | ---: |
| Import plus thumbnails | 1.027 s | 4.564 s |
| Reconstruction plus result preview | 1.846 s | 9.558 s |
| Peak RSS after import (`getrusage`) | 100,012,032 B | 182,755,328 B |
| Peak RSS after reconstruction (`getrusage`) | 100,012,032 B | 239,988,736 B |
| Actual retained raster arrays after reconstruction | 68,013,564 B | 211,890,424 B |
| Conservative reconstruction reservation, including display-copy allowance | 79,978,376 B | 247,021,168 B |
| Output joints, all exact | 2 | 9 |

These are single observations, not a latency guarantee or physical-device
memory policy. Process-lifetime peaks include runtime, encoded input and decoder
scratch space, allocation history and sampler overhead; they exclude fixture
generation. The Linux worker driver does not instantiate SwiftUI/CGImage or the
model scheduler. Current RSS snapshots in the raw reports use `smaps_rollup`;
separate kernel accounting/time points can differ slightly from `getrusage`.
The table consistently reports the existing `PeakMemorySampler` high-water value.

A separate real-model three-capture probe also completed with the exact source
fingerprint. The ten-capture model probe hit this environment's libdispatch
`_dispatch_workq_monitor_pools.cold.1` process-accounting crash and produced no
measurement report. The synchronous driver measures the same image operations
without that scheduler, and is explicitly labelled accordingly. No production
scheduling was changed to avoid the host failure. Apple ImageIO, simulator and
physical-device peaks remain unmeasured. The 256 MiB raster reservation remains
an experimental admission ceiling, not a hard RSS bound or device safety claim.

Raw reports and reproducible generator/worker source are in
[`native-png-probe`](native-png-probe/). From a Linux checkout with Swift 6.0.3,
first run the release build above, then:

```sh
probe_dir=$(mktemp -d /tmp/traktion-native-probe.XXXXXX)
build_dir="$PWD/.build/x86_64-unknown-linux-gnu/release"
source_dir="$PWD/docs/notes/native-png-probe"
swiftc -parse-as-library -O -I "$build_dir/Modules" \
  "$source_dir/GenerateNativeImportFixtures.swift" \
  "$build_dir"/TraktionDomain.build/*.swift.o \
  "$build_dir"/TraktionVision.build/*.swift.o \
  "$build_dir"/FixtureForgeKit.build/*.swift.o \
  -o "$probe_dir/generate"
swiftc -parse-as-library -O -I "$build_dir/Modules" \
  "$source_dir/ProbeNativeWorker.swift" \
  "$build_dir"/TraktionDomain.build/*.swift.o \
  "$build_dir"/TraktionVision.build/*.swift.o \
  "$build_dir"/TraktionCore.build/*.swift.o \
  "$build_dir"/TraktionUI.build/*.swift.o \
  "$build_dir"/FixtureForgeKit.build/*.swift.o \
  "$build_dir/TraktionLabEvaluation.build/PeakMemorySampler.swift.o" \
  -o "$probe_dir/probe"
"$probe_dir/generate" 3 "$probe_dir/phone"
"$probe_dir/generate" 10 "$probe_dir/long"
sha256sum "$probe_dir"/phone/*.png "$probe_dir"/long/*.png > "$probe_dir/originals.sha256"
"$probe_dir/probe" "$probe_dir/phone" "$probe_dir/phone-report.json"
"$probe_dir/probe" "$probe_dir/long" "$probe_dir/long-report.json"
sha256sum --check "$probe_dir/originals.sha256"
```

## Pre-publication gate and repository cleanup
Five actual-app simulator scenarios are implemented for import/order/success,
reordering, duplicate/gap refusals, reset, portrait/landscape, larger text and
real Files picker presentation/cancellation. At the local handoff, these scenarios had **not run**. Apple SwiftUI compilation,
ImageIO verification, simulator screenshots and remote CI were then pending.
The published verification below supersedes that gate status.

Automatic approval review rejected `github_create_tree` twice, saying direct
end-user authorization to publish the local payload to GitHub was required.
Read-only checks confirmed the authenticated repository owner, local origin,
current main and the already merged PR16/PR17. The second review still denied
publication. No alternate upload method was used; no remote branch, PR or merge
was created during that attempt. Sean subsequently explicitly approved all
GitHub interaction on 2026-09-09. That resolves the approval block; publish
`codex/native-png-workflow` to `VASEYDEV/TRAKTION`, run all CI lanes, then merge
only the verified head and delete the completed integration branch.

Three isolated implementation branches were integrated as commits `cf4ecb4`,
`78fa946`, `8e062bb` and `853e697`, then their clean worktrees and branches were
removed. The old PR-template worktree was clean and its full tree
matched merged `main`; it was also removed. At that handoff, only `main` and `codex/native-png-workflow` remained locally,
and the remote inventory contained only `main`. The implementation was committed
locally before publication.

## Published platform verification
Sean's explicit GitHub authorization resolved the publication block. PR #18
contains the verified implementation. [CI run 34304298288](https://github.com/VASEYDEV/TRAKTION/actions/runs/34304298288) passed the
repository, Linux, Apple package/PNG, iOS simulator and required-aggregator jobs.
Both Linux and Apple executed all 165 portable tests, PNG smoke, full 45/45
evaluation and fresh phone/long performance cases. Xcode 16.4 (16F6); iPhone SE (3rd generation), iOS 26.2: native
build, install, launch and all five UI tests passed. XCTest exercised actual
service import, confirmation/reorder, reconstruction, duplicate/gap refusals,
reset, rotation, larger text and real Files picker cancellation.

Six named screenshot attachments and xcresult are retained in the
[native artifact](https://github.com/VASEYDEV/TRAKTION/actions/runs/34304298288/artifacts/10086264945);
no manual visual inspection is claimed. The five UI tests completed in
136.520 seconds. Xcode used the iPhoneSimulator 18.5 SDK and iOS 17 deployment
minimum on the installed iOS 26.2 runtime. No physical-device, export or pixel-scale inspection
claim is added. Final-head verification and merge identifiers are recorded in
the PR; documentation-only follow-up changes retain the same required gates.
