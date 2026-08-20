# Architecture

> **Status: concept.** TRAKTION has no application code yet; this document records the
> intended shape so the first implementation has a target. Update it in the same PR as
> any change that alters it (CLAUDE.md §3).

## Big picture

TRAKTION is the input side of a two-tool pair:

- **VIZION** — the enhancement tool. It runs the enhancement itself.
- **TRAKTION** — the I/O prompting layer. It supplies the inputs that steer VIZION.

TRAKTION exists so VIZION does not have to be driven from a single monolithic, up-front
prompt. Intent is composed from small modular inputs, and those inputs can keep
influencing the enhancement while it runs.

## Intended components

Design intent, not yet built:

| Component | Responsibility |
| --- | --- |
| Input modules | Self-contained prompting building blocks that can be mixed per run |
| Composer | Assembles the selected modules into a concrete I/O payload for VIZION |
| Dynamic channel | Feeds adjustments to VIZION mid-run so the enhancement is influenced dynamically |
| Output tap | Reads VIZION output/state back so the next inputs can react to it (the "I/O" loop) |

These components surface to the user as **run flags** — the draft registry and its
precedence rules live in [`flags.md`](flags.md).

## Open questions

- Interface contract with VIZION (API, file drop, MCP, or in-process?).
- Stack selection — decides the package manager, real gate commands, and deploy target.
- Reconciling the draft-v0 flag registry in [`flags.md`](flags.md) with the owner's
  canonical list from the original design discussion.
