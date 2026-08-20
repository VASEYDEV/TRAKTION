@AGENTS.md

# Agent compatibility shim

All project behavior, architecture constraints, and acceptance rules are defined in `AGENTS.md`.

When this environment supports additional agent-specific features, use them only to execute the canonical repository contract. Do not create a second, conflicting policy layer here.

## Repository facts

Non-canonical operational facts for this repository; on any conflict, `AGENTS.md` wins.

- **Verification gate:** `bash scripts/gate.sh` (docs-stage checks, also run by CI). Replace it with the real clean-build and test commands in the same PR that introduces the Swift packages, per `FOUNDATION_CHECKLIST.md`.
- **License:** PolyForm Noncommercial 1.0.0, with a planned relicense to MIT at public open-sourcing (`docs/decisions/0002`). Do not change it without explicit owner approval; contributions must carry a grant permitting the MIT relicense.
- **Brand:** VASEY/AI, under the Vasey Studios umbrella (parent logo forthcoming). Never conflate with VASEY.AUDIO.
- **Logging:** working notes are dated files in `docs/notes/` (`YYYY-MM-DD-topic.md`); every meaningful change gets a `CHANGELOG.md` entry (Keep a Changelog + SemVer); README/CHANGELOG update in the same PR as the change they describe.
- **ADR tracks:** `docs/adr/` holds product and architecture ADRs (kit numbering `ADR-NNN`); `docs/decisions/` holds repo-governance ADRs (numbering `000N`).
