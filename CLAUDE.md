@AGENTS.md

# Agent compatibility shim

All project behavior, architecture constraints, and acceptance rules are defined in `AGENTS.md`.

When this environment supports additional agent-specific features, use them only to execute the canonical repository contract. Do not create a second, conflicting policy layer here.

## Repository facts

Non-canonical operational facts for this repository; on any conflict, `AGENTS.md` wins.

- **Verification:** `bash scripts/check-repository.sh` is portable policy validation; `bash scripts/verify-core.sh` builds/tests Swift; `bash scripts/gate.sh` is the complete macOS gate including Apple ImageIO fixture generation and decoded-pixel smoke comparison. CI runs repository, Linux core, and Apple lanes before its required aggregator.
- **License:** PolyForm Noncommercial 1.0.0, with a planned relicense to MIT at public open-sourcing (`docs/decisions/0002`). Do not change it without explicit owner approval; contributions must carry a grant permitting the MIT relicense.
- **Brand:** VASEY/AI, under the Vasey Studios umbrella (parent logo forthcoming). Never conflate with VASEY.AUDIO.
- **Logging:** working notes are dated files in `docs/notes/` (`YYYY-MM-DD-topic.md`); every meaningful change gets a `CHANGELOG.md` entry (Keep a Changelog + SemVer); README/CHANGELOG update in the same PR as the change they describe.
- **ADR tracks:** `docs/adr/` holds product and architecture ADRs (kit numbering `ADR-NNN`); `docs/decisions/` holds repo-governance ADRs (numbering `000N`).
- **Task tracking:** every coding assignment is a packet `docs/tasks/NNNN-topic.md` from `templates/TASK_TEMPLATE.md`, indexed with status in `docs/tasks/README.md`. Take the next free number from the index; numbers merged on `main` win over numbers on unmerged branches, and a superseded branch is ported, not merged. Tick acceptance boxes only from command evidence.
- **Toolchain:** CI's Linux lane is the `swift:6.0-noble` image; on a non-Apple host without Swift, install the matching swift.org toolchain (Swift 6.0.x, Ubuntu 24.04) before running `verify-core.sh`, `smoke.sh`, or `traktion-lab evaluate`. The Apple lane (`gate.sh`) runs only in CI unless you are on macOS.
- **Handoff:** report with `prompts/08_PR_HANDOFF.md`; a session note in `docs/notes/` records what was verified and what is left.
