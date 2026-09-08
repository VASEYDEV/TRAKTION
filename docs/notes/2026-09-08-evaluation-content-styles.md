# Evaluation content styles handoff — 2026-09-08

Task 0011 expands the deterministic corpus beyond its original light text
proxy. FixtureForge now exposes six content styles: light text, dark UI,
mixed photography, tables with one-pixel rules, monospaced code proxies, and
a block-quantized compressed-source proxy.

Each style runs in baseline, missing-middle, and duplicate configurations.
Ground-truth schema version 2 and evaluation-report schema version 3 record
the style explicitly. The generated patterns retain absolute-row evidence so
periodic visual structure does not manufacture an ambiguous registration.
An initial monospaced proxy did expose a missing-coverage false-safe; task
0014 records the finding and its deterministic line-number-gutter fix rather
than weakening or changing the expected failure.

Review should focus on deterministic byte generation, distinct fingerprints,
the failure expectations for missing and duplicate captures, and ensuring the
visual proxies remain diagnostics rather than claims about real-world image
coverage.
