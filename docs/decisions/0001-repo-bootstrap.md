# ADR 0001 — Bootstrap on the Vasey repo standard v3.0

**Date:** 2026-08-20 · **Status:** accepted

## Context

TRAKTION was a two-file repository (README stub + LICENSE). The Vasey Multimedia
Engineering Standard v3.0 (`CLAUDE.md`) is being installed and the required scaffold
created before any application code lands.

## Decisions

1. **Standard installed verbatim.** §1–§10 of `CLAUDE.md` are copied byte-identical from
   the source template; repo-specific facts live only in its "Project Notes" section.
2. **License stays the Unlicense.** The standard defaults to MIT, but this repo was
   created under the Unlicense — treated as "the project specifies otherwise" (§7).
   Swapping licenses requires explicit owner approval.
   *Superseded by [ADR 0002](0002-license-polyform-pending-mit.md) (2026-08-20): the
   owner directed a restrictive license; now PolyForm Noncommercial 1.0.0.*
3. **Shell gate until a stack exists.** There is no package.json or framework yet, so the
   §3 gate is `scripts/gate.sh` (required files present, no template placeholders,
   `CLAUDE.md` under 200 lines, no committed env files or key material), run locally and
   in CI. It must be replaced with real lint/typecheck/test/build in the same PR that
   introduces code.
4. **Brand assumed VASEY/AI.** TRAKTION and VIZION are AI tooling, so the AI-tools brand
   applies rather than VASEY.AUDIO (§10). Flagged for owner confirmation.
5. **No `.env.example`, no `docs/legal/`.** No environment variables exist and no
   user-facing service ships from this repo yet, per bootstrap steps 2 and 4.
6. **Notes convention.** Working notes are dated files in `docs/notes/`; every meaningful
   change also gets a `CHANGELOG.md` entry. Decisions graduate to ADRs in this folder.

## Consequences

- CI is green on a docs-only repository without faking a build.
- Future sessions know where to log (notes / CHANGELOG / ADRs) and exactly what to
  replace when application code lands.
