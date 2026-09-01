# 2026-09-01 — Milestone 1 audit (prompt 07): pass with follow-up

Independent audit of merged main `aaf5e69` per `prompts/07_MILESTONE_AUDIT.md`,
performed by a separate auditor session with no authorship of the audited
code, verifying from code it read and commands it ran — never from CHANGELOG,
PR bodies, or task-packet claims. All verification ran in a pristine clone of
`aaf5e69` (the shared checkout had begun Milestone 2 work mid-audit; see the
process finding below). This note is the writer's faithful condensation of
the auditor's report; the full report with its command appendix is preserved
in the session record.

## Verdict

**Pass with follow-up.** Milestone 1 as defined in docs/ROADMAP.md is
implemented; every Linux-verifiable claim held under independent
re-execution and adversarial probing. The Apple/ImageIO lane is credited as
CI-verified only (Actions run 33533… lane green on the exact SHA), not
locally reproduced.

## Independently reproduced evidence

- 67/67 tests, `check-repository`, `verify-core`, `smoke`, and the
  evaluation gate (16/16, 0 false-safe / 0 false-warning / 0 wrong-failure /
  0 nondeterministic) all pass in the pristine clone; evaluation reports
  byte-equal modulo timing; two-process CLI runs byte-identical
  (composites, manifests, diagnostics); inputs SHA-256-identical after all
  runs; overwrite refusal proven at CLI and codec layers.
- **No false-safe path found** (the audit's focus). ADR-013's early-exit
  bounds verified as true monotone lower bounds with exact completed scans;
  an adversarial probe hiding misplacement evidence in the lowest-edge-energy
  rows (the scan's worst case) still produced the unique true overlap with a
  byte-identical composite and 0 missing / 0 duplicated rows; genuinely
  periodic content surfaced every exact placement as `ambiguousOverlap`;
  budget exhaustion is typed on every path with no composite.
- `refinementRounds: 1` confirmed byte-for-byte equivalent to the
  pre-task-0005 algorithm (diff analysis + behavioral probe).
- Offline/non-destructive/no-secrets invariants hold structurally: zero
  network/telemetry/provider-SDK code, zero external dependencies, no
  tracked captures, defensive untrusted-PNG decoding (header-first caps,
  CRC/Adler verification, typed failures).
- Phone scale (1170×2532 pair), release CLI end-to-end: 2.5 s wall,
  ~128 MiB peak RSS.

## Follow-ups (none milestone-blocking, in the auditor's value order)

1. Genuine ambiguity beyond `candidateLimit` is mistyped: provably
   acceptable-many content (blank page, dense periodic) throws
   `resourceLimitExceeded` before the uniqueness check can label it
   `ambiguousOverlap`; the exact scores are already in hand after
   refinement. Fail-closed, but the typed cause is wrong.
2. Refinement survivors are re-scored from scratch (`score()`) after a
   completed early-exit scan already produced the exact score — up to 2× the
   acceptance-path cost, multiplied across Milestone 2's pairwise graph; the
   exact-row-hash scan is the one unbudgeted scan in the engine.
3. Evaluation harness skips pixel-provenance metrics (pixel equality / row
   accounting) for near-exact statuses (`degraded`, `scrollbar`); only the
   goldens cover provenance there.
4. `docs/ARCHITECTURE.md` and AGENTS.md disagree on where registration
   lives (Vision vs Core; the math is wholly in Core), and ARCHITECTURE.md
   promises Domain types that do not exist — reconcile before Milestone 2
   adds platform-backed registration.
5. Spec failure vocabulary incomplete at `aaf5e69`
   (`missingCoverage`/`ambiguousOrder`/`dynamicConflict`/
   `unsupportedTransform` unimplemented). *Status: `missingCoverage` and
   `ambiguousOrder` land with tasks 0006/0007 (ADR-014); the remaining two
   belong to later milestones.*
6. **Process finding:** the one-writer-per-branch rule was violated —
   Milestone 2 work began in the shared checkout while this audit was in
   flight. The audit isolated itself in a clone and its evidence is clean;
   acknowledged by the writer: sequencing discipline restored (audit
   deliverable lands before any further Milestone 2 increment, and future
   audits get a dedicated clone from the start).

Also noted for Milestone 2 planning: `JointConfidence.review/.gap/.conflict`
are declared but unreachable; duplicates are byte-equality only; per-joint
budgets have no sequence-level counterpart; the harness has no ordering
metrics at `aaf5e69` (first ordering cases land with task 0007);
FixtureForgeKit is not an exported product, so out-of-package tooling
cannot consume the generator.

Follow-ups 1–4 are queued as the next engine/tooling increment after the
task-0006/0007 review completes; they will be tracked task packets with
acceptance criteria before any code changes.
