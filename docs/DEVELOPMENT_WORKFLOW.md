# Agentic Development Workflow

## Rule: one writer, one reviewer

For any branch or pull request, one agent is designated Writer and a different agent or human may act as Reviewer. Reviewer does not silently rewrite the branch while reviewing. This applies regardless of model/provider.

## Task packet

Every coding assignment must include goal, why it matters, current behavior, required behavior, non-goals, allowed file paths, forbidden changes, fixtures, acceptance tests, build/test commands, required evidence, and reviewer. Use `templates/TASK_TEMPLATE.md`.

## Handoff packet

At completion, the Writer reports behavior implemented, files changed, architecture decisions, tests added, commands run and results, known limitations, risks, and recommended review focus. Use `prompts/08_PR_HANDOFF.md`.

## Reviewer behavior

Reviewer should read the task/acceptance criteria, inspect the diff, reproduce tests, attempt at least one failure-path check, identify unsupported assumptions, report findings by severity, and avoid broad rewrites unless explicitly assigned.

## Escalation

Use deeper reasoning or a second independent review when reconstruction output can silently corrupt content, destructive source actions are involved, persistence/undo correctness is at risk, memory behavior is unclear, privacy/security boundaries change, or repeated ordinary attempts have failed.
