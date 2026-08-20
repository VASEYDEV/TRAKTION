# Milestone 1 foundation handoff — 2026-08-20

## Behavior implemented

The repository now builds as a Swift package with the specified domain, core, vision, UI, optional-review boundary, diagnostic lab, fixture forge, and application-shell targets. The deterministic vertical engine reconstructs supplied equal-width PNG sequences and emits typed failures and reproducible JSON diagnostics.

## Architecture decisions

No new dependency was introduced. The PNG codec uses platform zlib through a Swift system-library target, keeping reconstruction offline and portable across Linux CI and Apple platforms. Semantic review remains disabled and cannot mutate pixels.

## Verification and limitations

Unit/golden coverage exercises two- and three-capture exact reconstruction and required false-safe failure cases. The end-to-end fixture compares the encoded composite byte-for-byte with its known source. Milestone 1 remains limited to supplied-order vertical, static, translation-only PNG captures; it does not infer gaps, ordering, fixed elements, or transforms.

## Review focus

Review overlap ambiguity behavior, integer row accounting at hard seams, typed failures, and the guarantee that only decoded source pixels enter the composite.
