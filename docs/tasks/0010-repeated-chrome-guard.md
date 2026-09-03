# Task: Repeated-chrome fixture and identical-band guard

Status: planned — **false-safe finding, highest priority engine task**
(found 2026-09-03 during the task-0008 handoff review; reproduction below).

## Goal
Captures whose top and bottom carry the same fixed viewport band never
produce a composite reported as `exact`; the condition is a typed failure
(or, once the editor exists, a visible `review` joint), and the control set
carries the fixture that proves it.

## Why it matters
`AGENTS.md` forbids converting a low-confidence reconstruction into a
successful result without reporting uncertainty. The supplied-order engine
currently does exactly that for one input family: when every capture starts
and ends with the same band (same-colour status and home bars, identical
toolbar art top and bottom), the band forms a short byte-exact suffix/prefix
overlap, the true content overlap is rejected because the band contaminates
it, ADR-012's uniqueness rule is satisfied by the wrong candidate, and the
composite duplicates documentary rows with every joint marked `exact`.

## Reproduction (merged `main` at `c061c92`, Linux, Swift 6.0.3)
Baseline control (`FixtureControlConfiguration(sourceID: "probe", seed: 99)`,
64×96 captures, overlap 24), then overwrite rows `0..<12` and `84..<96` of
every capture with the same deterministic 12-row band
(`SyntheticFixtureFactory.document(width: 64, height: 12, seed: 777)`):

| input | result | overlaps | confidence | rows missing / duplicated |
| --- | --- | --- | --- | --- |
| supplied order | **reconstructed** | `[12, 12]` (truth `[24, 24]`) | `exact`, `exact` | 22 / 46 |
| shuffled, `reconstructExactUnordered` | `ambiguousSequenceOrder` | — | — | — |

A solid black 8-row band top and bottom reconstructs the same way
(`[8, 8]`, 15 missing / 47 duplicated); solid bands of 12 or 16 rows refuse
with `ambiguousOverlap` only because uniform rows admit several exact
placements. The exact-ordering path refuses correctly because every capture
can follow every other.

## Current behavior
`register` accepts the unique acceptable overlap without checking whether
the matched band is explained by fixed viewport chrome rather than scroll
continuity. The control set has sticky-header and sticky-footer variants
(different bands, which fail safe as `insufficientOverlap`) but no variant
with the same band at both edges.

## Required behavior
1. FixtureForgeKit variant `.repeatedChrome(rows:)`: the same deterministic
   band painted at the top and bottom of every capture. Ground truth status
   `repeated-chrome`; the supplied-order pin is the new typed failure, the
   exact-ordering pin is `ambiguousSequenceOrder`. The variant joins the
   standard evaluation corpus under both policies (this is also the
   ordering-ambiguity case task 0008 left out).
2. Deterministic guard in `register`, after the unique acceptable overlap of
   `k` rows is chosen and only when `k` is a strict suffix of the preceding
   capture: if the matched band (following rows `0..<k`) is also byte-equal
   to the preceding capture's rows `0..<k`, or the preceding capture's tail
   `k` rows are byte-equal to the following capture's tail `k` rows, the
   band sits at the same viewport position in both captures and is not
   evidence of scrolling. Return a new typed failure
   (`repeatedInterfaceArtifact(preceding:following:rows:)` with a stable
   code) rather than a plan. The full-height prefix case
   (`testFullHeightOverlapAllowsFollowingCaptureToExtendDocument`) must keep
   reconstructing.
3. The guard must not change any positive control: baseline, one-pixel
   offset, degraded, scrollbar, overlap sweep, repeated-looking rows,
   phone-scale, and adaptive-refinement goldens pass byte-identically.
4. A hand-built legitimate repeat (content band `A` at the head of both
   captures with real scroll continuity) is recorded as the known
   false-warning cost of the guard, with a golden that pins the typed
   failure so a later confidence-based design can lift it deliberately.
5. Milestone 4 fixed-element detection may later downgrade this failure to
   a `review` joint with the band masked; that is a separate ADR.

## Non-goals
- Detecting different top and bottom bands (already fail safe).
- Masking or removing chrome from output (Milestone 4).
- Changing thresholds or budgets.

## Allowed scope
- `Packages/TraktionDomain/Sources/TraktionDomain/ReconstructionModels.swift`
- `Packages/TraktionCore/Sources/TraktionCore/ReconstructionEngine.swift`
- `Tools/FixtureForge/Sources/FixtureForgeKit/FixtureControlSet.swift`,
  `Tools/FixtureForge/Sources/FixtureForge/main.swift`
- `Tools/TraktionLab/Evaluation/EvaluationHarness.swift` (corpus cases)
- `Tests/Golden/`, `Tests/Unit/`
- `docs/adr/ADR-015-*.md` (or the next free number), `CHANGELOG.md`,
  `docs/notes/`, `docs/tasks/`, `README.md`

## Forbidden changes
- `TraktionVision`, `TraktionAI`, `TraktionUI`, CI, gate scripts,
  `AGENTS.md`.

## Inputs / fixtures
- The reproduction above (non-solid band, 12 rows; solid band, 8 rows).
- Every existing positive control.
- The full-height prefix golden.

## Acceptance criteria
- [ ] Both reproduction inputs return the new typed failure with no
      composite; the failure round-trips through Codable with a stable code.
- [ ] `repeated-chrome` is in the standard corpus under both policies with
      verdict `pass`; the corpus stays 0 false-safe.
- [ ] Every existing golden passes byte-identically.
- [ ] The legitimate-repeat false-warning golden is pinned and documented.
- [ ] ADR committed; tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Required evidence
- command output
- before/after evaluation report on the new case
- the reproduction table above re-run on the fixed engine

## Writer
Unassigned (engine writer; one writer per branch).

## Reviewer
Independent engine reviewer required before merge (false-safe review per
`AGENTS.md`; second review recommended per
`docs/DEVELOPMENT_WORKFLOW.md` escalation rule).
