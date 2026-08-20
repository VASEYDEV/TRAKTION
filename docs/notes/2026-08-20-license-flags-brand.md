# 2026-08-20 — License switch, flag registry, Vasey Studios

Owner directives from review of the bootstrap PR (#1):

1. **Flags:** include them in the README. The original design-chat list remains
   unavailable, so a draft-v0 registry was authored (`docs/flags.md`): `--trak`,
   `--grip`, `--drift`, `--steer`, `--lock`, `--tap`, `--dry` — traction-named, each
   mapped to an architecture component. Explicitly marked as a stand-in pending the
   owner's canonical list.
2. **License:** owner wants restrictive-now, MIT-later. Chose **PolyForm Noncommercial
   1.0.0** over BUSL 1.1 (no forced conversion date; owner stays sole gatekeeper) —
   rationale and relicensing path in ADR 0002. README Contributing now carries the
   inbound MIT-relicense grant.
3. **Brand:** VASEY/AI confirmed; new top-level umbrella will be **Vasey Studios**, logo
   forthcoming (ADR 0003). Footer/brand tokens updated; no Studios logo invented here.

## Still open

- Owner review of the draft flag registry against the original list.
- Vasey Studios logo lands in `assets/` when the owner supplies it.
- CLAUDE.md §7/§10 "Vasey Multimedia" rename — propose against the source template, not
  this repo's copy.
