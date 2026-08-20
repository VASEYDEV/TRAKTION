# ADR 0003 — Brand hierarchy: VASEY/AI under Vasey Studios

**Date:** 2026-08-20 · **Status:** accepted

## Context

ADR 0001 assumed the VASEY/AI brand for TRAKTION and flagged it for confirmation. The
owner confirmed VASEY/AI and added new information: the top-level conglomerate business
will be **Vasey Studios**, with its own logo forthcoming.

## Decision

- TRAKTION ships under **VASEY/AI**, which sits under the **Vasey Studios** umbrella.
- Repo copy that references the parent (README footer, brand tokens) says
  "a Vasey Studios project" rather than "Vasey Multimedia".
- No Vasey Studios logo is created in this repo — the owner's forthcoming mark is
  authoritative. When it lands, add the source SVG to `assets/` and reference it where
  the parent brand appears.
- `CLAUDE.md` §7/§10 still name "Vasey Multimedia" (e.g. the MIT copyright default). Those
  sections are byte-identical standard text this repo must not edit; the Vasey Studios
  rename should be proposed against the source template. Until then, the repo-local truth
  lives in Project Notes and this ADR.

## Consequences

- Footer and brand docs are consistent with the announced structure without inventing a
  logo that doesn't exist yet.
- A single place (this ADR) explains why the standard's §7/§10 text and the repo's brand
  copy temporarily disagree about the parent-company name.
