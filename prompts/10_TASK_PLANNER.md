# Prompt: Convert a Feature Request into an Agent Task

Given a TRAKTION feature request, produce one implementation task using `templates/TASK_TEMPLATE.md`.

Rules:
- scope so one writing agent can own it,
- name concrete modules when known,
- separate required behavior from non-goals,
- define measurable acceptance criteria,
- include at least one failure-path test,
- preserve architecture boundaries,
- do not introduce semantic review where deterministic processing is sufficient,
- identify whether an ADR is required.

Do not implement the feature in this step.
