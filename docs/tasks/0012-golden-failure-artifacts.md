# Task: Golden-failure CI artifact bundle

Status: planned (Milestone 1 audit follow-up, §2).

## Goal
When a golden or evaluation case fails in CI, the run retains the bundle
`docs/EVALUATION.md` prescribes: expected image, actual image, absolute
difference image, reconstruction manifest, and per-joint diagnostics.

## Why it matters
Today a failing golden reports a pixel mismatch assertion and nothing else;
the reviewer cannot see where the composite diverged without reproducing
locally. The Apple lane retains synthetic smoke diagnostics only.

## Current behavior
Golden tests compare rasters in memory. `traktion-lab evaluate` writes a JSON
report only. The Linux lane uploads `evaluation-report.json`.

## Required behavior
1. `traktion-lab evaluate --artifacts-dir <dir>` writes, for every case whose
   verdict is not `pass` (or, with `--all-artifacts`, every reconstructable
   case): `expected.png`, `actual.png`, `difference.png`, the reconstruction
   manifest, and per-joint JSON/difference PNGs, under
   `<dir>/<case-name>/`. Nothing is written for passing cases by default.
2. The Linux CI lane passes an artifacts directory and uploads it with
   `if: failure()`; artifact retention excludes anything outside the
   synthetic corpus.
3. A golden test helper writes the same bundle to a `TRAKTION_GOLDEN_ARTIFACTS`
   directory when set, so `verify-core.sh` failures are inspectable too.
4. The difference image is the existing `differenceImage` output (absolute
   channel difference, opaque), never a blended or annotated raster.

## Non-goals
- Image viewers, HTML reports, or thumbnails.
- Changing what constitutes a failure.

## Allowed scope
- `Tools/TraktionLab/`, `Tests/Golden/`, `.github/workflows/ci.yml`
  (upload step only), `scripts/verify-core.sh` (env pass-through only)
- `CHANGELOG.md`, `docs/runbooks/verification.md`, `docs/notes/`,
  `docs/tasks/`

## Forbidden changes
- `Packages/*` behavior, FixtureForge, gate semantics.

## Acceptance criteria
- [ ] A fabricated failing case produces the full bundle; a passing corpus
      produces no artifacts.
- [ ] CI uploads the bundle only on failure.
- [ ] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json --artifacts-dir /tmp/evaluation-artifacts
```

## Writer
Unassigned.

## Reviewer
Independent reviewer required before merge.
