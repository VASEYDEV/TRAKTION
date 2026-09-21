# Dependencies and build environment

Initial audit: 2026-09-17; scoped persistence and CI update: 2026-09-21. This inventory describes the checked-in package, Xcode
project and Actions workflow. It is not a claim that every future upstream
version is compatible or that simulator verification establishes device readiness.

| Layer | Current dependency | Reason / ownership |
| --- | --- | --- |
| App and engine | Swift 6; local SwiftPM modules only | No external Swift package or model SDK; `Package.swift` is the inventory |
| Native UI | Apple SwiftUI, Observation, Foundation, Dispatch | Native workspace and cancellable worker orchestration |
| Apple PNG/raster boundary | CoreGraphics, ImageIO, UniformTypeIdentifiers | Platform image decoding and Files import |
| Linux PNG/raster boundary | Repository-owned pure-Swift PNG codec | Same tested pixel contract without an external codec |
| OS bindings | Darwin / Glibc | Platform system calls and process diagnostics |
| Tests | XCTest; deterministic FixtureForge | Source-pixel, golden, lifecycle, resource and native UI evidence |
| Minimum targets | iOS 17, macOS 14 | Xcode build settings and SwiftPM platform declarations |
| Linux CI | Ubuntu 24.04, official `swift:6.0-noble` container | Main audit observed Swift 6.0.3 |
| Apple CI | `macos-15`, installed Xcode | Main audit observed Xcode 16.4, Swift 6.1.2, iOS 26.2 simulator |
| Scripts | Bash, Python 3 standard library | Repository/manifest/test-inventory checks; no pip dependencies |
| Checkout action | `actions/checkout` at `3d3c42e5aac5ba805825da76410c181273ba90b1` | v7.0.1; Node 24 runtime |
| Artifact action | `actions/upload-artifact` at `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | v7.0.1; Node 24 runtime |

There is no app network/API-key requirement. `TraktionAI` remains a provider-neutral
contract with no active semantic-review provider. Private captures and credentials
must never be committed or uploaded as CI evidence.

## Updating dependencies

Record a concrete compatibility/security reason before introducing an external
package; explain why the platform stack is insufficient in an ADR. Update action
pins deliberately, identify their upstream release/commit, and require every CI
lane. The Swift container and hosted runner images can change underneath their
version labels; retained logs record the actual compiler/Xcode/simulator used.
Do not equate a green Linux job with Apple ImageIO or native SwiftUI coverage.

The current audit found no external Swift dependency to upgrade and no evidence
that a dependency defect caused the retained failing workflows. Previous failures
and their fixes are recorded in the [health note](notes/2026-09-17-repository-health.md).

## Task 0022 delta — 2026-09-21

Local projects add Foundation security-scoped URL access and `NSFileCoordinator`
at the Files boundary, plus the existing Darwin/Glibc bindings for exclusive temp
creation, private staging-directory creation and atomic no-clobber `link`. The framed container
uses standard-library/Foundation encoding and streaming file handles. It adds no
archive framework, external package, network client or model dependency. This is
a scoped implementation update, not a new audit of all upstream versions.
Saving stages outside the chosen folder and requires same-filesystem hard-link
support; unsupported locations fail closed without an external file-copy library.

## CI action runtime update — 2026-09-21

[Run 35564839626](https://github.com/VASEYDEV/TRAKTION/actions/runs/35564839626)
reported deprecated Node 20 action pins and an upcoming `ubuntu-latest` image
migration. The workflow now pins
[checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) and
[upload-artifact v7.0.1](https://github.com/actions/upload-artifact/releases/tag/v7.0.1)
by their verified release commits, and uses `ubuntu-24.04` for the repository and
required jobs as well as Linux. The Swift container, Apple runner, read-only
permissions, required lanes and assertions are unchanged.

The observed runner version, 2.337.0 on all three completed repository/Linux/Apple
jobs, satisfies Node 24's minimum 2.327.1 and checkout's conditional 2.329.0
requirement for authenticated Git in Docker actions. Checkout's temporary
credential storage and upload's default zipped archives, wildcard paths,
compression, hidden-file exclusion and unique names fit the existing workflow.
The updated pins executed successfully in all lanes in
[run 35569321865](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865)
at `5821eac`: all five jobs passed, both evaluation reports and native evidence
were retained, and completed logs contained no Node 20 deprecation warnings.
Every later pushed head still requires the full gate; final verification belongs
in PR #21.
