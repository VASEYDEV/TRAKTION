# TRAKTION Reconstruction Specification

## Objective

Given overlapping captures of one continuous visual document or viewport, reconstruct a continuous output without visible duplication, omission, ghosting, or seam artifacts when source coverage is sufficient.

## Pipeline

### 1. Ingest
Resolve orientation, preserve original assets, record source dimensions/metadata, and assign stable identifiers.

### 2. Normalize
Generate working representations without mutating originals: canonical orientation, working color representation, grayscale proxy, edge proxy, and optional downsampled pyramid. Initial milestone requires equal pixel width for vertical sequences.

### 3. Candidate overlap search
For adjacent captures A and B, search plausible overlap lengths between the bottom region of A and top region of B. Use coarse-to-fine search.

### 4. Registration
Estimate relative translation. Prefer integer translation first; subpixel translation only when necessary. Affine/homographic transforms belong to later milestones and require evidence. Screenshot reconstruction should strongly prefer integer-pixel placement to avoid softened text.

### 5. Seam selection
Choose a seam inside the valid overlap. Priority: exact-identical region, low-difference flat region, whitespace, low-edge-density region, then a low-cost path that avoids glyphs and high-contrast features. Do not feather through text in normal screenshot mode.

### 6. Compose
Render from original-resolution pixels using the validated transform and seam.

### 7. Validate
Evaluate every joint for duplicated rows/columns, omitted rows/columns, OCR discontinuity, sudden edge discontinuity, baseline jump, unexpected margin shift, repeated interface artifact, unexplained gap, and mismatch between predicted and realized overlap.

### 8. Confidence
Assign `exact`, `strong`, `review`, `gap`, or `conflict`.

## Ordering

Later milestones create a pairwise overlap graph. Each plausible directed pair receives a score based on registration quality, overlap length, OCR continuation, edge continuity, and expected capture geometry. The sequence solver chooses the best path while detecting reversed captures, duplicates, misplaced captures, and missing coverage.

## Fixed and transient regions

Later milestones classify regions as scrolling content, fixed UI, transient/dynamic content, device/browser chrome, or unknown. Evidence includes relative motion across frames/captures.

## Video reconstruction

Screen-recording reconstruction should extract candidate frames, estimate scroll trajectory, reject redundant frames, identify direction reversals, recover content from alternate frames where fixed elements occlude it, and choose the cleanest source for each content coordinate.

## Failure policy

Never fabricate missing documentary content. Return typed states such as `insufficientOverlap`, `missingCoverage`, `incompatibleDimensions`, `dynamicConflict`, `ambiguousOrder`, or `unsupportedTransform`.

## Determinism

Given identical inputs and settings, the deterministic engine should produce identical reconstruction plans and output bytes where codecs permit.
