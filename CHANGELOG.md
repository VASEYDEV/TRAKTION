# Changelog

All notable changes to TRAKTION are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
