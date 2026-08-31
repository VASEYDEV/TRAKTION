# 2026-08-21 — Deterministic Swift foundation

## Scope

Task 0001 begins actual development on a Codex-owned branch stacked on the Foundation Kit
PR. The branch intentionally separates writing ownership from Claude's completed kit
installation branch.

## Implemented

- One dependency-free Swift 6 package with the specified module/tool boundaries.
- Immutable tightly packed RGBA8 evidence buffers and stable capture/plan/diagnostic types.
- Supplied-order vertical overlap search with stable row hashes, deterministic sampling,
  full-resolution candidate verification, ambiguity rejection, and typed failures.
- Half-open seam/source spans rendered once from original pixels.
- Apple ImageIO opaque-PNG adapter, diagnostic Lab, deterministic FixtureForge baseline,
  and a read-only SwiftUI preview shell.
- Synthetic golden/failure/determinism/performance/PNG tests and a three-lane CI gate.
- Admissible sampled-score lower bounds plus explicit sampling, full-comparison, input,
  output, and PNG decode budgets; unresolved candidates fail closed.

No production semantic-review provider, provider SDK, OCR, ordering, horizontal path,
sticky-element handling, video, web capture, or generative pixel behavior was added.

## Local evidence

- `bash scripts/check-repository.sh` — pass
- shell syntax checks for all verification scripts — pass
- tracked JSON parsing — pass
- `git diff --check` — pass

## CI evidence

GitHub Actions run
[`32529179089`](https://github.com/VASEYDEV/TRAKTION/actions/runs/32529179089)
passed the repository policy lane, Swift 6 Linux build/tests, macOS build/tests, Apple PNG
round-trip, FixtureForge → TraktionLab reconstruction, decoded composite equality, and the
required-check aggregator. The pull request remains draft for independent review and
because it is stacked on the Foundation Kit pull request.
