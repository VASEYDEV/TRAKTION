# Task: Evaluation corpus visual categories

Status: planned (Milestone 1 audit follow-up, §2).

## Goal
Every fixture category named in `docs/EVALUATION.md` that the engine can be
evaluated against today exists as a distinct, deterministic standard
evaluation case with ground truth.

## Why it matters
The audit accepted Milestone 1 on a corpus whose content is one synthetic
document style. Light text, dark UI, mixed text/photography, tables and thin
rules, monospaced code, and compressed-source inputs are not represented, so
the zero false-safe finding is evidence for one input family only.

## Current behavior
`SyntheticFixtureFactory.document` renders a single light-background text
proxy; all control-set variants and the overlap sweep derive from it.

## Required behavior
1. FixtureForgeKit gains deterministic content styles (a `contentStyle` on
   `FixtureControlConfiguration`): light text, dark UI, mixed photography
   (deterministic gradient/noise blocks), tables with one-pixel rules,
   monospaced code (fixed-pitch glyph proxies), and a compressed-source
   proxy (deterministic block-quantization, still opaque PNG).
2. Each style is generated for the baseline shape and the missing-middle and
   duplicate controls; ground truth records the style.
3. The standard evaluation corpus and `fixture-forge generate --style` expose
   them; the report's per-case record names the style.
4. Any style that exposes a false-safe is reported as a defect finding, not
   pinned as an expectation (task 0003 rule 5).

## Non-goals
- Dynamic-region fixtures (need a temporal model; Milestone 5).
- OCR and edge-continuity metrics (separate task once a text proxy with
  known glyph positions exists).
- Engine changes.

## Allowed scope
- `Tools/FixtureForge/`, `Tools/TraktionLab/Evaluation/`
- `Tests/Golden/`
- `CHANGELOG.md`, `docs/notes/`, `docs/tasks/`

## Forbidden changes
- `Packages/*`, CI, gate scripts.

## Acceptance criteria
- [ ] Each style generates byte-identically across two runs.
- [ ] Standard corpus reports 0 false-safe across all styles, or the defect
      is filed as its own task.
- [ ] Tests pass deterministically; no unrelated diff.

## Build / test commands
```sh
bash scripts/check-repository.sh
bash scripts/verify-core.sh
swift run traktion-lab evaluate --output /tmp/evaluation-report.json
```

## Writer
Unassigned.

## Reviewer
Independent reviewer required before merge.
