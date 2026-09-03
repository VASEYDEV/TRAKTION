# Task: Fail-closed exact sequence ordering

## Goal
Recover one documentary order from an unordered set of 2–10 captures when, and
only when, exact suffix-to-prefix pixel evidence proves a unique complete path.

## Why it matters
Milestone 2 begins with order recovery, but choosing locally plausible matches
can silently reorder documentary content. The first increment must establish a
deterministic, bounded, ambiguity-aware contract before near-exact scoring is
considered.

## Current behavior
`ReconstructionEngine.reconstruct` requires supplied sequence order. Reversed
or shuffled input fails rather than attempting to infer order.

## Required behavior
1. Add an opt-in exact-unordered core entry point; preserve supplied-order API
   behavior byte for byte.
2. Build directed edges only from exact suffix-to-prefix overlaps of at least
   `minimumOverlapRows` and accept exactly one Hamiltonian path.
3. Return typed failures when no complete path exists or multiple paths exist.
4. Make traversal and ambiguity diagnostics independent of input permutation.
5. Bound total pairwise comparison work and fail before selecting from a
   partially examined graph.

## Non-goals
- Near-exact order recovery, OCR, feature matching, or local-best heuristics.
- Duplicate removal, missing-coverage repair, or horizontal reconstruction.
- Changing supplied-order registration, seams, compositing, or output pixels.
- CLI or UI exposure.

## Allowed scope
- `Packages/TraktionDomain/Sources/TraktionDomain/`
- `Packages/TraktionCore/Sources/TraktionCore/`
- `Tests/Unit/TraktionDomainTests/`
- `Tests/Golden/`
- `docs/adr/`, `docs/tasks/`, `docs/notes/`, `CHANGELOG.md`, `README.md`

## Forbidden changes
- `TraktionVision`, `TraktionAI`, `TraktionUI`, tools, CI, and gate scripts.

## Inputs / fixtures
- Shuffled baseline captures.
- Missing-middle control.
- Synthetic captures with identical exact boundaries in both directions.

## Acceptance criteria
- [x] Shuffled exact captures reconstruct in documentary order with source-pixel equality.
- [x] Different input permutations produce identical plans and output pixels.
- [x] Missing coverage returns `sequenceOrderNotFound`.
- [x] Multiple complete orders return `ambiguousSequenceOrder` with no output.
- [x] Exhausted ordering budget returns `resourceLimitExceeded` with no partial choice.
- [x] New failures round-trip through Codable and have stable codes.
- [x] Complete repository gates pass deterministically.
- [x] No unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Required evidence
- command output
- exact-order golden results
- unchanged supplied-order evaluation report

## Writer
Codex (branch `work`)

## Reviewer
Independent engine reviewer required before merge.
