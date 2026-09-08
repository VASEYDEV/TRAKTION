# Evaluation content styles handoff — 2026-09-08

## Scope

Task 0011 broadens deterministic evaluation evidence without changing the
shipping engine. FixtureForge now supports six content styles: light text,
dark UI, mixed gradient/noise photography, one-pixel table rules, fixed-pitch
code glyph proxies, and block-quantized compressed-source pixels.

Each style is represented in the standard corpus by baseline,
missing-middle, and duplicate-capture controls. Ground truth schema version 2
and evaluation report schema version 3 record the style explicitly.

## Evidence

Two-run golden checks prove stable source pixels, captures, ground truth, and
distinct source fingerprints for every style. The 43-case standard evaluation
reports 43 passes and zero false-safe, false-warning, wrong-failure, or
nondeterministic outcomes.

An early monospaced-code implementation was too periodic: its baseline
returned `ambiguousOverlap`, and its missing-middle control returned the wrong
failure. The final generator retains the source's deterministic background
variation behind fixed-pitch glyphs, providing unique documentary anchors
without changing engine thresholds or pinning the exposed failures as
expected behavior.

## Review focus

Confirm that style generation is deterministic and visually/category-wise
distinct, that all three control shapes retain honest ground truth, and that
no engine or CI files changed.
