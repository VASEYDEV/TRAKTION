# ADR 0002 — PolyForm Noncommercial 1.0.0 now, MIT at open-sourcing

**Date:** 2026-08-20 · **Status:** accepted · Supersedes decision 2 of [ADR 0001](0001-repo-bootstrap.md)

## Context

The owner wants a relatively restrictive license while TRAKTION incubates, with a planned
move to MIT when the project is open-sourced later. The repo previously carried the
Unlicense (public domain — the opposite of restrictive), so a change was required.

## Options considered

- **PolyForm Noncommercial 1.0.0** — professionally drafted, plainly written,
  source-available. Permits noncommercial use, modification, and sharing; reserves all
  commercial use. No built-in expiry, so the owner controls the timing of the MIT switch.
- **Business Source License 1.1** — encodes "restrictive now, open later" with a
  mandatory Change Date (≤ 4 years) and Change License. Rejected for now: it commits to a
  conversion date up front and needs parameters (Additional Use Grant) that are premature
  for a docs-only project.
- **PolyForm Strict 1.0.0** — "look, don't touch" (no modification or distribution).
  Rejected as more restrictive than needed for a project that wants eventual community.
- **All rights reserved (no license)** — maximally restrictive but signals nothing about
  intent and blocks even harmless experimentation.

## Decision

Adopt **PolyForm Noncommercial 1.0.0**, verbatim from
<https://polyformproject.org/licenses/noncommercial/1.0.0.txt>
(sha256 `ffcca38841adb694b6f380647e15f17c446a4d1656fed51a1e2041d064c94cc8`), with the
required notice line `Required Notice: Copyright 2026 Sean Vasey`.

## Relicensing path to MIT

- Sean Vasey is currently the sole rights holder, so relicensing to MIT is a
  one-commit change whenever he chooses — no date pressure, no consent gathering.
- To keep it that way, external contributions are accepted only with a grant permitting
  the future MIT relicense (stated in the README's Contributing section). Without this,
  every outside contributor would later have to consent.
- Code contributed before the switch remains additionally available under PolyForm NC to
  anyone who already received it; the MIT grant applies from the switch forward.

## Consequences

- The project is publicly readable and usable for study, research, and hobby work, but
  nobody can commercialize it while it incubates.
- The prior Unlicense grant on the two-line README stub of the first commits is
  irrevocable for that historical content; it covers nothing added since 2026-08-20 and
  has no practical effect.
