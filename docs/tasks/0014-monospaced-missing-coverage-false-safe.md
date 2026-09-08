# Task: Monospaced missing-coverage false-safe

Status: resolved during task 0011

## Finding

The first monospaced-code proxy repeated on a short period. When the middle
capture was removed, registration accepted a false overlap and produced a
composite. This was treated as a false-safe defect, never as expected output.

## Resolution

The fixture now includes a deterministic absolute-row line-number gutter,
matching the evidence real code views provide while preventing the synthetic
proxy itself from erasing document position. The baseline remains exact and
the missing-middle control returns its pinned `insufficientOverlap` failure.

## Acceptance criteria

- [x] Monospaced baseline reconstructs exactly.
- [x] Monospaced missing coverage fails closed.
- [x] Standard evaluation corpus contains zero false-safe outcomes.
