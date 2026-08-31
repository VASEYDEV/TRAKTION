# Foundation Checklist

- [x] Copy package into repository root.
- [x] Confirm `AGENTS.md` is canonical.
- [x] Confirm environment-specific instruction files only reference the canonical contract.
- [x] Create native package/target layout.
- [x] Establish clean-build command (`swift build`).
- [x] Establish test command (`swift test`).
- [x] Establish CI (Linux gate + macOS build/test).
- [x] Create `TraktionLab` (`traktion-lab ingest`; `reconstruct` tracked by prompt 01).
- [x] Create `FixtureForge` (bootstrap controls; full control set tracked by prompt 02).
- [x] Commit synthetic baseline fixtures (`Tests/SyntheticFixtures/baseline-vertical-3`).
- [x] Keep private real-world captures ignored.
- [ ] Implement Milestone 1 without model integration.
- [ ] Require golden comparisons before claiming seamless reconstruction.
- [ ] Record any architecture deviation as an ADR.
