# ADR 0004 — Adopt Foundation Kit v1; AGENTS.md becomes canonical

**Date:** 2026-08-20 · **Status:** accepted · Supersedes the product framing in ADR 0001 and the v3.0-standard-at-root arrangement

## Context

The owner uploaded `TRAKTION_Foundation_Kit_v1.zip` to `main` (commit `423fabd`). The kit is
"the canonical starting point for agentic development of TRAKTION" and redefines the
product: a native Swift precision-reconstruction utility that stitches overlapping
screenshots, scroll captures, and recording frames into one continuous image — replacing
the earlier concept framing ("modular I/O prompting for the VIZION enhancement tool").

## Decisions

1. **Kit installed verbatim at repo root** per its `README_FIRST.md`, all 49 files
   verified against `MANIFEST.json` sha256 checksums. The zip was removed from the tree
   (recoverable from history); `.gitignore.append` was folded into `.gitignore` and
   removed.
2. **`AGENTS.md` is the canonical contract.** `CLAUDE.md` is the kit's compatibility shim
   plus a short non-canonical "Repository facts" section (gate command, license rule,
   brand, logging convention, ADR tracks). The Vasey Multimedia Engineering Standard v3.0
   text that previously lived in `CLAUDE.md` is retired from the root per the kit's
   "no second, conflicting policy layer" rule; it remains in git history (`e702c93`) and
   its still-operative repo specifics live on in the facts section.
3. **Product docs superseded:** concept-stage `docs/architecture.md` removed (it also
   case-collided with the kit's `docs/ARCHITECTURE.md` on case-insensitive filesystems);
   draft-v0 `docs/flags.md` retired — the kit defines no run-flag surface, and the
   VIZION-influencing framing it described is no longer the product. `README.md`
   rewritten to the kit's product statement, design invariants, modes, and confidence
   states.
4. **Two ADR tracks:** `docs/adr/` (kit, product/architecture, `ADR-NNN`) and
   `docs/decisions/` (repo governance, `000N`). New product ADRs use
   `templates/ADR_TEMPLATE.md`.
5. **Gate unchanged, plus `AGENTS.md` required.** `scripts/gate.sh` remains the CI gate
   until the Swift packages land with real build/test commands (`FOUNDATION_CHECKLIST.md`
   items). No Swift scaffolding was created in this change: this environment has no Swift
   toolchain, and `AGENTS.md` requires running build/test commands before declaring
   completion — Milestone 1 bootstrap (`prompts/00_BOOTSTRAP_AGENT.md`) belongs in a
   Swift-capable environment.

## Consequences

- The repo is the kit's intended starting state: contract, spec, prompts, and templates
  in place; governance (license, brand, logging) preserved and reconciled.
- Historical concept docs stay retrievable in git history; the licensing and brand
  decisions (ADR 0002, 0003) are unaffected by the pivot.
