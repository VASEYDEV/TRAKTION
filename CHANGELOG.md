# Changelog

All notable changes to TRAKTION are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-08-20

### Added

- **Run-flag registry, draft v0** (`docs/flags.md` + README "Run flags" table): seven
  traction-named flags (`--trak`, `--grip`, `--drift`, `--steer`, `--lock`, `--tap`,
  `--dry`) mapping 1:1 to the architecture's components, with precedence rules and open
  questions. Design spec only — nothing implemented yet.
- ADR 0002 (license switch) and ADR 0003 (brand hierarchy).

### Changed

- **Brand hierarchy recorded:** VASEY/AI now sits under the forthcoming **Vasey Studios**
  umbrella; README footer and `assets/brand-tokens.md` updated (no Vasey Studios logo in
  this repo until the owner's forthcoming mark lands).
- README "Status & flags" split into a compact status table and the new run-flag
  registry.

- **License replaced: Unlicense → PolyForm Noncommercial 1.0.0** (owner decision,
  [ADR 0002](docs/decisions/0002-license-polyform-pending-mit.md)). TRAKTION is now
  source-available for noncommercial use only while it incubates; the plan of record is a
  relicense to MIT at public open-sourcing. **Upgrade note:** anything obtained from the
  repo before this change remains public domain under the Unlicense; everything from
  0.2.0 onward is PolyForm NC.
- README Contributing section now states the inbound relicense grant (contributions must
  permit the future MIT switch).

## [0.1.0] - 2026-08-20

### Added

- Vasey Multimedia Engineering Standard v3.0 installed at repo root (`CLAUDE.md`) with Project Notes filled for TRAKTION.
- Repository scaffold: `.claude/` (settings, hooks, skills, commands), `.github/workflows/`, `docs/` (architecture, decisions, runbooks, notes), `assets/`, `scripts/`.
- Governance documents: `SECURITY.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `.editorconfig`, `.gitignore`.
- Brand assets: TRAKTION icon and wordmark SVGs plus brand tokens (`assets/`).
- Verification gate for the docs-only stage: `scripts/gate.sh`, run locally and in CI (`.github/workflows/ci.yml`) on every PR and push to `main`.
- First architecture decision record: `docs/decisions/0001-repo-bootstrap.md`.
- Working-notes convention under `docs/notes/` with the bootstrap session note.

### Changed

- README rewritten from a two-line stub to the §8 front-page spec: logo, tagline, badges, status flags, design goals, quick start, and brand footer.

## [0.0.1] - 2026-08-15

### Added

- Initial repository: README stub and the Unlicense.

### Changed

- Project renamed from AKTION to TRAKTION; description updated.
