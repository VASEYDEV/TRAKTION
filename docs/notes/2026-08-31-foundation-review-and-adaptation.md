# 2026-08-31 — Foundation review, merge, and cross-platform adaptation

One session, three phases, on branch `claude/traktion-dev-setup-f24qtq`.

## 1. Prompt-00 bootstrap (superseded, kept in history)

Executed `prompts/00_BOOTSTRAP_AGENT.md` from the docs-only repo state:
buildable package, pure-Swift PNG codec, `fixtureforge`/`traktion-lab ingest`,
33 tests, gate/CI upgrade (commit `8a84d44`, PR #5, CI green on Linux+macOS).
Superseded the same day when the owner chose PR #4 as the surviving foundation;
the useful pieces were ported (below), the rest removed in the reconciling
merge commit.

## 2. Independent engine review of PR #4 (`dd2dd76`)

Performed the merge-gate review the owner requested on the PR (prompt 04).
Reproduced `check-repository.sh` and `verify-core.sh` (21/21 tests, Linux),
the `[8, 20]` competing-overlap and periodic-ambiguity regressions, and three
out-of-suite adversarial probes (blank-document sub-minimum overlap, blank
duplicates, degenerate 2-row overlap) — all fail-closed. Verdict: approve, no
merge-blocking findings; process findings were the unratified
`RECONSTRUCTION_SPEC.md` edit and missing ADRs. Full report on PR #4.
Owner ratified and merged (`45dc17e`).

## 3. Adaptation on the merged foundation (this PR)

- Pure-Swift PNG codec (`PurePNGCodec`, `PureDeflate.swift`) as the non-Apple
  backend of the unchanged `PNGCodec` contract → `PNGCodec.isAvailable`
  everywhere; Linux runs the full smoke (fixture → reconstruct → compare →
  diagnostics → failure-cleanup) and CI's Linux lane now executes it.
- Parity tests across backends + CPython-zlib/PNG interop vectors (base64,
  generated once with CPython's `zlib`; the tRNS and alpha≠255 vectors pin the
  opaque-input contract on both backends).
- `VisualReviewDecision` aligned to `config/visual-review-decision.schema.json`;
  disabled + mock adapters; contract tests.
- ADR-011 (codec boundary + fallback), ADR-012 (unique acceptable translation,
  ratified), closing the review's process findings.

Verified this branch: `bash scripts/check-repository.sh`,
`bash scripts/verify-core.sh` (40/40 tests), `bash scripts/smoke.sh` on Linux
(PASS, decoded pixels match exactly; failure path cleans up). The macOS gate
runs in CI's Apple lane.
