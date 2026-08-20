# TRAKTION run flags — draft v0

> **Status: design spec, draft v0 (2026-08-20). Not implemented.** This registry defines
> the intended input surface so the first implementation has a contract to build against.
> The owner's canonical flag list supersedes this draft when supplied; when it changes,
> update the README table in the same PR (CLAUDE.md §3).

## Design rules

1. **Flags are the modular inputs.** Every flag maps 1:1 to an input module or channel in
   [`architecture.md`](architecture.md) — no flag exists without a component behind it.
2. **Traction vocabulary.** Names come from the driving metaphor — *trak, grip, drift,
   steer, lock* — so the surface stays memorable and on-brand ("Be Right on TRAK").
3. **Composable by default.** Any combination of flags must behave predictably; conflicts
   resolve by the precedence rules below, never by surprise.
4. **Repeatable where plural.** `--steer` and `--lock` may appear multiple times per run;
   the rest appear at most once.

## Registry

| Flag | Kind | Component | Effect |
| --- | --- | --- | --- |
| `--trak <name>` | module stack | Composer | Loads the named stack of input modules as the run's baseline intent. Defaults to the `base` trak when omitted. |
| `--grip <0–100>` | influence weight | Composer | How firmly the composed inputs hold VIZION to the baseline intent. 100 = strict adherence, 0 = suggestions only. |
| `--drift` | latitude | Composer | Grants VIZION latitude to explore beyond the composed intent, bounded by the current grip. Off by default. |
| `--steer <input>` | live input | Dynamic channel | Injects one adjustment into the running enhancement. Repeatable; applied in order given. |
| `--lock <aspect>` | constraint | Composer | Pins a named aspect (e.g. `subject`, `palette`, `composition`) against any change. Repeatable. |
| `--tap` | feedback | Output tap | Streams VIZION's output state back to the composer so subsequent inputs can react to it. Off by default. |
| `--dry` | safety | Composer | Composes and prints the full I/O payload without sending anything to VIZION. Off by default. |

## Precedence and combination

- `--lock` beats everything: a locked aspect ignores `--steer` adjustments and `--drift`
  exploration that would touch it.
- `--grip` and `--drift` interact rather than conflict: grip sets how hard the baseline
  pulls, drift widens where VIZION may wander within that pull.
- `--dry` short-circuits the run after composition — nothing reaches VIZION, so
  `--steer`/`--tap` have nothing to act on and are reported as inert.
- Unknown flags fail the run before composition; TRAKTION never silently drops input.

## Open questions

- Whether flags surface as a CLI, API parameters, UI controls, or all three — decided
  with the stack.
- A file-based equivalent for saved runs (a *trakfile*) so stacks and flag sets are
  reproducible.
- The canonical flag list from the owner's original design discussion — this draft stands
  in until that list is supplied and reconciled.
