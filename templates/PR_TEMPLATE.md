<!--
Keep this handoff concise. Complete the common sections; delete conditional
sections that do not apply. Link detailed task evidence instead of copying logs.
AGENTS.md is authoritative. Report failures, blocked checks, and uninspected
artifacts explicitly; do not treat scheduled CI or test discovery as a pass.
Keep templates/PR_TEMPLATE.md identical to this GitHub default template.
-->

## Summary

<!-- What problem matters, what changed, and what can the user/tool now do? -->

## Scope and ownership

- Task / issue and acceptance criteria:
- Writer / independent reviewer:
- Affected modules or workflows:
- Dependencies on other PRs, superseded work, or remaining scope:

<!-- Use docs/tasks/README.md and current main; identify intentional milestone
expansions. Distinguish shipping behavior from scaffolding and future plans. -->

## Changes

<!-- Describe the implementation and important tradeoffs. Link ADRs for changed
architecture/contracts and justify new dependencies against the platform stack.
Call out manifest/project/schema compatibility and any migration required. -->

## Verification

- Tested commit SHA:
- Tests added or changed / acceptance criteria demonstrated:

| Environment / toolchain / build mode | Exact command or CI job link | Result and evidence |
| --- | --- | --- |
| | | |

<!-- Record executed test counts, failures, and artifact links as applicable.
Use docs/runbooks/verification.md and docs/runbooks/ios-development.md for current
commands. Separate Linux core/PNG, Apple ImageIO, and native iOS simulator results.
Include the final-head CI run and verification / required status when available;
otherwise mark pending. Explain unavailable checks and any command substitutions.
For documentation-only changes, repository/whitespace checks suffice locally;
state that runtime tests were not run. Existing CI requirements still apply. -->

- Not run, blocked, or pending checks (with reason):

## Reconstruction and resource evidence (if applicable)

<!-- For engine, codec, ordering, fixture, evaluation, or export changes. -->

- Reproduction: fixture/case, seed, dimensions, capture count/order, and command:
- Expected versus actual: output pixels/order/joints or typed failure; before/after regression evidence:
- Evaluation: cases passed/total; false-safe, false-warning, wrong-failure, and nondeterminism counts:
- Artifacts: genuine source truth, actual composite/difference, manifest, and joint diagnostics where available:
- Performance: workload, platform/build mode, timing, peak memory/scope, and budget changes:

<!-- Preserve the original failing input and independent oracle; do not make an
engine defect disappear by weakening fixtures/assertions. Check missing/duplicated
rows, ambiguity, and fail-closed resource limits. Retain both outcomes for
nondeterminism; typed refusals may have no composite. Use synthetic-only CI
artifacts. Label process-lifetime RSS separately from engine allocations or
physical-device measurements; performance advisories do not prove correctness. -->

## Native app and editing evidence (if applicable)

- Exercised flow and failure/cancellation behavior:
- Device or simulator, OS, orientation, and screenshots/recording actually inspected:
- Accessibility: larger text, VoiceOver/labels, and relevant interaction checks:
- Source integrity and state: import/reset/replacement, undo/redo or persistence/export checks as relevant:

<!-- For asynchronous image work, cover off-main execution, one active operation,
stale completions, and retained memory. State what was tested versus deferred.
Separate simulator build/install/launch from physical-device signing/distribution. -->

## Contract and privacy impact

<!-- State "Unchanged" with a brief basis, or explain the affected boundaries and
evidence: deterministic pixel authority; no invented content or silent gaps;
non-destructive originals; offline reconstruction/editing/persistence/export;
UI/core separation. For AI/network changes, retain at most one active optional
semantic provider, typed/validated recommendations, and minimized payloads;
never upload the final long image by default. Do not attach private captures,
credentials, or signing material. -->

## Risks and review focus

- Known limitations / regressions to watch:
- Files, decisions, or failure paths needing independent review:
- Follow-up task links; rollback or migration considerations when relevant:

<!-- Update task acceptance status and affected docs/ADRs/runbooks. Leave no
unrelated diff. Resolve review findings with evidence tied to the reviewed commit. -->
