# Prompt: Produce a Pull Request Handoff

Prepare a concise implementation handoff for the reviewer.

Use `.github/pull_request_template.md`, GitHub's default PR body, as the
handoff structure. `templates/PR_TEMPLATE.md` is its synchronized portable copy.
Remove inapplicable conditional sections and link detailed task evidence.

Include:
- Behavior implemented
- Files changed
- Architecture decisions or ADR changes
- Tests added/changed
- Exact commands run and pass/fail results
- Generated composites, difference artifacts, screenshots, or manifests relevant to the change
- Known limitations
- Risks
- Recommended review focus

Do not claim success for anything not verified by a command, test, or observable artifact.
