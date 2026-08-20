# Runbook — verification gate

## Run it locally

```bash
bash scripts/gate.sh
```

Exit code 0 and a final `GATE: PASS` line mean the repo standard holds.

## What CI runs

`.github/workflows/ci.yml` runs the same script on every pull request and every push to
`main`, so local and CI verification never diverge.

## What the gate checks today (docs-only stage)

1. Required files exist: `README.md`, `LICENSE`, `CHANGELOG.md`, `SECURITY.md`,
   `CODE_OF_CONDUCT.md`, `CLAUDE.md`, `.editorconfig`, `.gitignore`.
2. No unfilled double-brace template placeholders remain outside `docs/legal/`.
3. `CLAUDE.md` stays under 200 lines (§2 context-hygiene rule).
4. No env files are committed (`.env.example` excepted) and no private-key material
   appears anywhere in the tree (§5).

## When application code lands

Replace the shell checks with the real §3 gate — lint · typecheck · unit ·
integration · build — in the same PR that introduces the code, and update this runbook.
