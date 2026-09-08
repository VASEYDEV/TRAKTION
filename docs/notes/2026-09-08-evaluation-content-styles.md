# Evaluation content styles handoff — 2026-09-08

**Superseded resolution:** the gutter adjustment below improved the synthetic
positive fixture but did not repair the engine's acceptance of the original
pixels. Task [0014](../tasks/0014-monospaced-missing-coverage-false-safe.md)
preserves that input and records the engine repair and remaining limits in
[ADR-018](../adr/ADR-018-bidirectional-near-exact-evidence.md).

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
