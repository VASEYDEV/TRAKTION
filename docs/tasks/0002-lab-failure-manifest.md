# Task: Typed failure manifest for traktion-lab

## Goal
A failed `traktion-lab reconstruct` run leaves a deterministic, machine-readable
failure manifest naming the typed failure, instead of only stderr text.

## Why it matters
EVALUATION.md treats diagnostics as CI artifacts and AGENTS.md requires explicit
state over silent behavior. Today a typed engine or decode failure produces no
artifact at all (independent review of PR #4, finding Low-1), so automated
harnesses cannot distinguish failure modes without parsing stderr.

## Current behavior
`Tools/TraktionLab/Sources/main.swift` decodes inputs, runs the engine, then
publishes composite/manifest/diagnostics. Any thrown error reaches the top-level
catch: message to stderr, exit 1. Publication failures additionally remove all
created artifacts.

## Required behavior
1. `TraktionDomain.ReconstructionFailure` conforms to `Codable`.
2. When input decoding fails (`PNGCodecError`) or the engine throws
   `ReconstructionFailure`, the Lab writes the manifest path as a failure
   manifest: `schemaVersion`, `algorithmVersion`, `status: "failed"`, `stage`
   (`"decode"` or `"reconstruct"`), a stable `failureCode`, a human-readable
   `failureDescription`, the typed `reconstructionFailure` (reconstruct stage
   only), the captures decoded before the failure, and all supplied input file
   names. Exit code stays non-zero; stderr still reports the failure and the
   manifest path.
3. The success manifest gains `status: "reconstructed"`; `schemaVersion` becomes
   2 for both shapes.
4. Publication failures (IO after successful reconstruction) keep the existing
   remove-everything-and-fail behavior; no failure manifest is written there.
5. Deterministic output: sorted keys, no timestamps; identical inputs produce
   identical failure manifests.

## Non-goals
- Engine behavior changes of any kind.
- Partial per-joint diagnostics on failure (requires engine support; later task).
- Changing `compare` or CLI argument surface.

## Allowed scope
- `Packages/TraktionDomain/Sources/TraktionDomain/ReconstructionModels.swift`
- `Tools/TraktionLab/Sources/main.swift`
- `Tests/Unit/TraktionDomainTests/`
- `scripts/smoke.sh`
- `CHANGELOG.md`, `docs/notes/`

## Forbidden changes
- `Packages/TraktionCore/`, `Packages/TraktionVision/`, `Packages/TraktionUI/`,
  `Packages/TraktionAI/`, `Tools/FixtureForge/` (task 0003 owns that),
  CI workflow, gate scripts other than `smoke.sh`.

## Inputs / fixtures
- `fixture-forge baseline` output (existing)
- A duplicated capture path (duplicate-capture failure, reconstruct stage)
- A non-PNG byte file (decode-stage failure)

## Acceptance criteria
- [x] `ReconstructionFailure` round-trips through Codable for every case.
- [x] Duplicate-capture run exits non-zero and writes a failure manifest with
      `status: failed`, `stage: reconstruct`, `failureCode: duplicateCapture`,
      and a decodable `reconstructionFailure`.
- [x] Corrupt-input run writes `stage: decode` with the offending file named in
      `failureDescription`; captures decoded before the failure are listed.
- [x] Two identical failing runs produce byte-identical failure manifests.
- [x] Forced publication failure still leaves no artifacts (existing smoke check).
- [x] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
```

## Writer
Claude (branch `claude/traktion-dev-setup-f24qtq`)

## Reviewer
Independent reviewer required before merge.
