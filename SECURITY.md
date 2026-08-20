# Security Policy

## Reporting a vulnerability

Email **sean@vasey.audio** with a description of the issue, steps to reproduce, and any relevant logs. Please do not open public issues for security reports. You can expect an acknowledgement within 7 days.

## Supported versions

TRAKTION is pre-alpha and no application code has shipped yet. Until a first release, security reports are assessed against the tip of `main` only.

| Version | Supported |
| --- | --- |
| `main` (unreleased) | ✅ |

## Product security constraints

This file covers vulnerability reporting for the repository. The application's own
security and privacy invariants (source integrity, minimal remote payloads, private
fixtures) live in [`docs/SECURITY.md`](docs/SECURITY.md) and
[`docs/PRIVACY.md`](docs/PRIVACY.md), enforced through [`AGENTS.md`](AGENTS.md).

## Audit exceptions

None. Per the engineering standard (`CLAUDE.md` §6), `audit` criticals block merge; any documented exception would be recorded here.
