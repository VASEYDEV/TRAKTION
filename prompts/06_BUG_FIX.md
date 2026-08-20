# Prompt: TRAKTION Bug Fix

Fix the reported defect with the smallest correct change.

## Procedure
1. Reproduce the bug.
2. Add or identify a test/fixture that fails for the bug.
3. Classify the responsible layer: domain logic, registration, seam selection, validation, rendering, UI state, persistence, or export.
4. Fix only the responsible layer.
5. Verify the regression test.
6. Run the broader relevant suite.
7. Report root cause and exact commands run.

Do not suppress the warning/error, relax thresholds without evidence, route deterministic failures to semantic review as a shortcut, or refactor unrelated code.
