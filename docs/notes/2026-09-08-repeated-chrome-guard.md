# Repeated-chrome guard handoff — 2026-09-08

## Repository audit

The working tree started clean at merge commit `e8a2f4d`. The checkout had a
single local branch and ref (`work`) and no configured remotes or additional
worktrees, so there was no locally visible unmerged development. Remote pull
request and deleted-branch state could not be independently queried from this
checkout. The task index identified task 0010 as the highest-priority open
false-safe engine finding.

## Behavior implemented

- Added a stable typed `repeatedInterfaceArtifact` failure.
- Added the deterministic same-position edge-band guard without changing
  pixel selection or the full-height-prefix behavior.
- Added a deterministic `repeated-chrome` FixtureForge scenario and supplied
  and exact-ordering evaluation cases.
- Pinned non-solid and solid-band reproductions plus the conservative
  legitimate-content false warning.

## Reproduction after the fix

| input | policy | result | output |
| --- | --- | --- | --- |
| deterministic 12-row repeated chrome | supplied | `repeatedInterfaceArtifact` (12 rows) | none |
| deterministic 12-row repeated chrome | exact ordering | `ambiguousSequenceOrder` | none |
| solid black 8-row repeated chrome | supplied | `repeatedInterfaceArtifact` (8 rows) | none |

The standard evaluation corpus contains 25 cases, all pass, with zero
false-safe, false-warning, wrong-failure, or nondeterministic results.

## Review focus

Independently reproduce the two viewport-edge comparisons, verify that the
strict-suffix condition preserves full-height prefix extension, and inspect
the pinned legitimate-repeat false warning before considering a less
conservative confidence design.
