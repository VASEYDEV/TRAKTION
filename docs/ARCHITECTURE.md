# TRAKTION Architecture

## Platform direction

Initial implementation is a native Swift and SwiftUI application with a shared Swift reconstruction core.

Recommended Apple frameworks include SwiftUI, Photos/PhotosUI, Vision, Accelerate/vImage, Core Image, Metal where useful, AVFoundation, ReplayKit, and WebKit. External dependencies require justification.

## Repository layout

```text
TRAKTION/
├── App/TRAKTION/
├── Packages/
│   ├── TraktionDomain/
│   ├── TraktionCore/
│   ├── TraktionVision/
│   ├── TraktionUI/
│   └── TraktionAI/
├── Tools/
│   ├── TraktionLab/
│   └── FixtureForge/
├── Tests/
│   ├── Golden/
│   ├── SyntheticFixtures/
│   ├── RealWorldFixtures/
│   ├── Performance/
│   └── UITests/
├── docs/
├── prompts/
├── templates/
├── AGENTS.md
└── CLAUDE.md
```

## Package responsibilities

### TraktionDomain
Pure types and contracts. No UI framework and no model-provider SDK dependency.

Representative types: `CaptureAsset`, `CaptureSequence`, `ReconstructionAxis`, `OverlapCandidate`, `RegistrationResult`, `JointDiagnosis`, `JointConfidence`, `ReconstructionPlan`, `ReconstructionResult`, `EditCommand`, `ExportPreset`.

### TraktionCore
Provider-independent reconstruction orchestration: normalization policy, overlap candidate generation, sequence solving, seam selection, continuity validation, reconstruction plan generation, deterministic project state.

### TraktionVision
Platform-specific computer vision and image operations: OCR observations, translation registration, edge/difference generation, pixel operations, frame extraction, viewport-motion analysis.

### TraktionUI
User-facing canvas and editing components. No direct model-provider calls. No ownership of reconstruction mathematics.

### TraktionAI
Optional semantic review only. Must expose a provider-neutral interface such as `VisualReviewer`. Expected implementations are disabled reviewer, mock reviewer, and one production provider adapter. No provider-specific type may escape this package.

### TraktionLab
A command-line or diagnostic app that calls the same shipping core used by the main application. It emits reconstructed output, per-joint diagnostics, machine-readable reconstruction manifest, and difference artifacts on failure.

### FixtureForge
Produces deterministic source canvases and overlapping capture sequences with known ground truth.

## Data flow

```text
Source Assets
    ↓
Normalize
    ↓
Candidate Overlaps
    ↓
Register
    ↓
Sequence / Joint Plan
    ↓
Seam Selection
    ↓
Continuity Validation
    ↓
[optional semantic review only if ambiguity is semantic]
    ↓
Validated Reconstruction Plan
    ↓
Tile Renderer
    ↓
Editor / Export
```

## Architectural rule

Semantic review may influence a reconstruction plan only through typed recommendations. A deterministic validator must accept or reject the recommendation before it changes output behavior.
