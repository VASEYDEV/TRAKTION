# 2026-08-20 — Foundation Kit v1 installed; product pivot

The owner uploaded `TRAKTION_Foundation_Kit_v1.zip` to `main` (from their Codex design
sessions) and asked to proceed; a Codex checkout was blocked (no git remote, no `gh`
auth), but this session has full repo access, so the work happened here.

## Done

- Verified repo state: PR #1 merged, its branch already deleted, **zero open PRs** — the
  GitHub cleanup Codex intended was already complete.
- Installed the kit verbatim at repo root (49/49 `MANIFEST.json` checksums verified),
  removed the zip, folded `.gitignore.append` into `.gitignore`.
- `AGENTS.md` is now canonical; `CLAUDE.md` is the kit shim + repository facts
  (ADR 0004). The v3.0 engineering-standard text left the root (git history keeps it).
- README rewritten to the real product: precision reconstruction of overlapping
  screenshots/scroll captures into one continuous image. VIZION framing and the draft
  run-flag registry retired — the kit mentions neither.

## Resolved questions

- **"Flags":** the kit contains zero flag definitions; the draft `--trak/--grip/...`
  registry described the retired concept and was removed. The only canonical state
  vocabulary is the joint confidence states (`exact`/`strong`/`review`/`gap`/`conflict`),
  now in the README.

## Open items

- **Milestone 1 bootstrap** (`prompts/00_BOOTSTRAP_AGENT.md`): needs a Swift-capable
  environment (macOS/Xcode or Swift toolchain); this Linux container has none, and
  `AGENTS.md` forbids declaring completion without running build/test commands.
- Replace `scripts/gate.sh` with real clean-build + test commands when packages land.
- Vasey Studios logo still forthcoming; repo About description still carries the old
  AKTION text (manual Settings → About edit).
