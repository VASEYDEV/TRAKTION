# Prompt: Independent Engine Review

Act as an independent reviewer, not the implementation agent. Read the task, `AGENTS.md`, reconstruction spec, evaluation plan, and diff.

## Review priorities
1. Can the change silently duplicate or omit source pixels?
2. Can a low-confidence result be misreported as safe?
3. Is the implementation deterministic?
4. Are unsupported inputs rejected explicitly?
5. Are memory copies unnecessarily amplified?
6. Did tests encode intended behavior or merely the current implementation?
7. Were any assertions weakened?
8. Do golden fixtures compare against independent ground truth?

Re-run documented tests, attempt at least one adversarial/failure fixture, and report findings by severity using `templates/REVIEW_REPORT_TEMPLATE.md`. Do not rewrite the implementation unless separately assigned.
