# TRAKTION Evaluation Plan

## Quality authority

Golden fixtures with known source canvases are the primary objective measure of reconstruction correctness.

## Fixture categories

At minimum: light text, dark UI, mixed text/photography, tables and thin rules, monospaced code, repeated list items, repeated-looking rows, overlap from 10–80%, one-pixel offsets, compressed source, duplicate capture, reversed capture, missing middle capture, width mismatch, sticky header, fixed footer, floating-button occlusion, scrollbar, dynamic region, and horizontal sequence.

## Metrics

### Exact fixtures
- output pixel equality against source
- missing-row count
- duplicated-row count
- seam-difference energy
- reconstruction determinism

### Approximate fixtures
- registration error
- OCR continuity
- edge continuity
- false-safe rate
- false-warning rate

### Ordering
- correct sequence rate
- duplicate identification rate
- missing-capture detection rate

### Semantic reviewer
- sticky-region classification
- duplicate vs legitimate repeat
- missing-coverage diagnosis
- dynamic-conflict classification
- correct abstention
- false-safe rate

False-safe errors are more severe than false warnings.

## Performance
Track ingest latency, pair registration latency, peak memory, preview latency, export throughput, and very-long-canvas behavior.

## CI artifacts
On golden-test failure, retain expected image, actual image, absolute-difference image, reconstruction manifest, and per-joint diagnostics.
