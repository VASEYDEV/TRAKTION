# Repository layout

| Path | Role |
| --- | --- |
| `App/TRAKTION.xcodeproj` | Native iOS app and XCTest UI targets, shared `TRAKTION` scheme |
| `App/TRAKTION/Sources` | SwiftUI entry point shared by Xcode and the SwiftPM macOS preview |
| `App/TRAKTION/Config` | Common build settings; developer signing overrides are ignored by git |
| `Package.swift` | Local Swift package products, tools, and portable test targets |
| `Packages/TraktionDomain` | Raster/capture values and typed reconstruction contracts |
| `Packages/TraktionCore` | Deterministic reconstruction, registration, ordering, and diagnostics |
| `Packages/TraktionVision` | Apple ImageIO, portable PNG codec, and atomic PNG preflight/import |
| `Packages/TraktionUI` | MainActor workspace, serial image worker, and shared SwiftUI workflow |
| `Packages/TraktionAI` | Optional semantic-reviewer interface; no active model dependency |
| `Tools/TraktionLab` | Diagnostic CLI, evaluation, failure artifacts, memory/throughput reports |
| `Tools/FixtureForge` | Deterministic synthetic fixtures and genuine source truth |
| `Tests/Unit`, `Tests/Golden`, `Tests/Performance`, `Tests/Integration` | Portable domain/engine/codec, workspace lifecycle, real PNG pipeline, and evaluation contracts |
| `Tests/UITests` | Native import/order/result/refusal/reset, picker cancellation, rotation, and text-size checks |
| `Tests/SyntheticFixtures`, `Tests/RealWorldFixtures` | Fixture metadata and private-capture boundary |
| `scripts` | Repository, Swift, PNG smoke, and native simulator verification |

The native target links the repository's local package. There is no external
package download or Xcode project generator. Pixel inspection, editing, persistence, and export remain future native workflows.

The Lab remains the executable reconstruction and diagnostic path:

```sh
traktion-lab reconstruct --axis vertical --output composite.png capture-001.png capture-002.png capture-003.png
```

It writes `composite.reconstruction.json` and per-joint difference diagnostics.
Current reconstruction scope is vertical, 2–10 equal-width opaque PNG captures,
static content, and translational overlap. Supplied order and optional exact
or near-exact order recovery are supported; uncertainty is a typed failure.
See the task index for capability limits and the verification/iOS runbooks
for actual build and simulator commands.
