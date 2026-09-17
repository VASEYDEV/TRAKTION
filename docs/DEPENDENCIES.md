# Dependencies and build environment

Audit date: 2026-09-17. This inventory describes the checked-in package, Xcode
project and Actions workflow. It is not a claim that every future upstream
version is compatible or that simulator verification establishes device readiness.

| Layer | Current dependency | Reason / ownership |
| --- | --- | --- |
| App and engine | Swift 6; local SwiftPM modules only | No external Swift package or model SDK; `Package.swift` is the inventory |
| Native UI | Apple SwiftUI, Observation, Foundation, Dispatch | Native workspace and cancellable worker orchestration |
| Apple PNG/raster boundary | CoreGraphics, ImageIO, UniformTypeIdentifiers | Platform image decoding and Files import |
| Linux PNG/raster boundary | Repository-owned pure-Swift PNG codec | Same tested pixel contract without an external codec |
| Tests | XCTest; deterministic FixtureForge | Source-pixel, golden, lifecycle, resource and native UI evidence |
| Minimum targets | iOS 17, macOS 14 | Xcode build settings and SwiftPM platform declarations |
| Linux CI | Ubuntu 24.04, official `swift:6.0-noble` container | Main audit observed Swift 6.0.3 |
| Apple CI | `macos-15`, installed Xcode | Main audit observed Xcode 16.4, Swift 6.1.2, iOS 26.2 simulator |
| Scripts | Bash, Python 3 standard library | Repository/manifest/test-inventory checks; no pip dependencies |
| Checkout action | `actions/checkout` at `11d5960a326750d5838078e36cf38b85af677262` | Exact v4 commit resolved in the audited passing main run |
| Artifact action | `actions/upload-artifact` at `ea165f8d65b6e75b540449e92b4886f43607fa02` | Exact v4 commit resolved in the audited passing main run |

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
