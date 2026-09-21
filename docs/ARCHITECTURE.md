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
`ProjectRestorer` recomputes automatic evidence from saved originals and accepts
only reproducible evidence with validated committed seams, returning the result
and a document with fresh undo/redo history.

### TraktionVision
Platform-specific computer vision and image operations: OCR observations, translation registration, edge/difference generation, pixel operations, frame extraction, viewport-motion analysis.

### TraktionUI
User-facing canvas and editing components. No direct model-provider calls. No ownership of reconstruction mathematics. The read-only inspector samples existing
result/original pixels into a bounded off-main viewport and resolves joint metadata
from the existing plan (ADR-022). Deliberate seam editing uses the Core source-strip
renderer and validated metadata-only history (ADR-023).

`LocalProjectStore` owns project framing, coordinated file access and atomic
publication, delegating reconstruction/evidence acceptance and restored seams to
Core's `ProjectRestorer` (ADR-024). The workspace serial queue performs save/open I/O; cancellation,
draining and job identity guard all-or-nothing publication on the main actor.
No file payload is trusted as pixel authority.
Save publication reads from an exclusively owned private staging directory,
outside the selected Files folder. Same-filesystem hard links protect the new
destination without exposing the source name to other selected-folder writers;
unsupported destinations fail closed.

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

## Local project boundary

Version 1 embeds exact original PNG bytes and bounded metadata, without source
paths, cached previews or a flattened output. Imports retain encoded bytes from
their validated private staging copy. Opening validates framing and PNG structure,
then reruns the engine and requires saved automatic evidence to match. The final
committed plan may differ only in valid seam positions; undo/redo starts empty.

Encoded retention has a separate 128 MiB aggregate budget and 64 MiB per-capture
limit. Owned rasters retain the existing 256 MiB budget, including originals,
worst-case output, thumbnails and display/preview copies. Both admissions count
the existing and incoming workspaces before replacement. These limits describe
owned retention, not process RSS or platform decoder internals.

All saves publish through an atomic no-clobber link under a cancellation commit
lock after a complete flush. An occupied destination requires a new filename;
validation followed by rename cannot safely bind an uncoordinated replacement.
Cleanup failures remain visible and distinguish an already saved destination.
The [ADR](adr/ADR-024-local-project-container.md) records framing, provider limits
and large-project arithmetic.
