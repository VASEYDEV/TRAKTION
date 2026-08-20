# TRAKTION Product Specification

## Product statement

TRAKTION is a precision reconstruction utility for turning overlapping screenshots, scroll captures, screen-recording frames, and related visual fragments into one continuous, editable image.

Its primary job is to restore content captured in pieces back into the continuous form in which it originally existed.

## Core problem

Full-page screenshot systems often fail when content scrolls inside a nested frame, headers or footers remain fixed, floating controls cover content, the source application has no full-page capture, the page is dynamic, or the user must capture a sequence manually.

Manual stitching is slow because adjacent captures contain overlapping content that must be aligned and trimmed precisely.

## Primary workflow

1. Import captures.
2. Establish or infer sequence.
3. Reconstruct.
4. Inspect only uncertain joints.
5. Correct with reversible manual tools when necessary.
6. Cut or trim unwanted regions.
7. Export in a suitable format and quality.
8. Optionally manage original captures after export.

## Product goals

- Seamless reconstruction when source coverage is sufficient.
- Fast automatic alignment.
- Clear uncertainty reporting.
- Excellent manual fallback.
- Non-destructive editing.
- Local-first operation.
- Useful handling of sticky and fixed viewport elements.
- Extremely long image support through tiled processing.
- Output controls that preserve screenshot clarity.

## Non-goals for initial releases

- General photographic panorama stitching.
- Generative recreation of missing documentary content.
- Image beautification or creative retouching.
- Social network features.
- Chat-first interaction.
- Multi-agent runtime orchestration.

## Modes

### Screenshots
Import overlapping screenshots and reconstruct vertically or horizontally.

### Scroll Recording
Extract useful frames from a screen recording, estimate scroll motion, and reconstruct the scrolling content.

### Web Capture
Use native document capture when possible; fall back to viewport reconstruction where required.

## Editor capabilities

- Joint inspector
- Ghost overlay
- Difference visualization
- Edge visualization
- Pixel loupe
- Fine nudge
- Magnetic snap
- Source selection
- Internal cut range
- Top/bottom/side trim
- Undo/redo
- Recalculate one joint
- Preserve/remove repeated fixed UI
- Non-destructive project persistence

## Confidence states

- `exact`
- `strong`
- `review`
- `gap`
- `conflict`

A low-confidence state must remain visible until resolved, explicitly accepted, or exported with an acknowledged warning.

## Product personality

TRAKTION should feel like an instrument: direct, calm, visual, precise, and fast. Advanced reconstruction should be present without turning the interface into an AI dashboard.
