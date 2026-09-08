# Repository continuation — 2026-09-08

## Starting state

Reviewed `main` at `6cb004c5944ef5d8c039574762270ec4b2166170`.
The foundation, exact/near-exact ordering, repeated-chrome guard, and six
synthetic visual categories were already merged (PRs #4–#13). Main's
[CI run 34270681528](https://github.com/VASEYDEV/TRAKTION/actions/runs/34270681528)
passed. GitHub reports `main` is unprotected with no enforced status checks
or associated rulesets; this continuation still requires all repository CI
lanes and independent review before merging. No protection configuration was
changed. The current standard evaluation corpus contains 43 cases, not the
README/runbook's former 23. There were no open GitHub issues.

## Supersession and branch inventory

PR #14 was closed as superseded by #13, with a disposition in its body.
Its engine/failure code matches main; merging the alternate fixture/docs
implementation would create conflicts and duplicate declarations. It also
predates main's task-0014 packet. The independent review retained the current
main implementation and preserved the original false-safe evidence separately.

| Branch | Reviewed head | Disposition |
| --- | --- | --- |
| `claude/repo-init-traktion-9ybpqc` | `9d6d77c35ba54d8ac0961ad12b683b0b978e4f01` | Fully merged ancestor of main; eligible for deletion |
| `claude/traktion-dev-setup-f24qtq` | `2a62b19c2b695ee3762e27b6326ec8c0d3cd12ab` | PR #8 and later reconciliation fully superseded by #10/#12; eligible for deletion |
| `codex/check-development-state-and-resume` | `b5d090899cb7773524db3e948a293062a3c04a2c` | PR #14 closed as superseded; eligible for deletion |

Deletion remains pending: the connected GitHub toolset provides no delete-ref
action, direct Git push has no credentials in this workspace, and GitHub
rejected secure browser sign-in because this account does not support
password sign-in. The branch names and exact reviewed heads above make the
remaining cleanup concrete; do not delete a branch if its head has advanced.
No protection rules, account permissions, or credentials were changed.

## Correctness findings

Task 0014 had been incorrectly declared resolved by adding an absolute-row
gutter to its fixture. The original unanchored monospaced source still gives
one accepted 57-row forward near-exact overlap across a real 48-row gap,
plus a plausible 30-row reverse overlap. Preserve those original pixels in
an independent regression. ADR-018 describes the bounded directional
ambiguity guard and the remaining limits of pixel similarity.

A newly completed Cursor review on PR #14 also identified a defect inherited
from main: the chrome guard compared the accepted overlap with itself when
a shorter following image was a full-height suffix. The containment regression
must reconstruct unchanged, while repeated viewport chrome must still refuse.

## App boundary and next work

The repository is an experimental reconstruction core, CLI, fixture generator,
and macOS preview shell. It does not yet have an Xcode iOS application target,
a signed installable app, Photos import, editor persistence, or app export UI.

After task 0012 failure-artifact retention and the bounded task-0014 repair,
continue with task 0013 measured memory/throughput evidence, then the native
Xcode target and simulator CI. Keep the later editor and capture modes as
explicit milestones; do not treat CLI evidence as app acceptance.

## Integrated verification

The combined change was reviewed independently for engine mathematics and
resource bounds, artifact truth/collision handling, and final test integration.
The preserved input bytes, capture windows, oracle expectations, and original
assertions are unchanged. Known-source gap and suffix regressions are now
wrapped by the failure-artifact helper too.

Swift 6.0.3, Linux, in this cloud workspace:

```sh
swift build --build-tests --configuration release --use-integrated-swift-driver -j 2 -Xswiftc -enable-testing
TRAKTION_GOLDEN_ARTIFACTS=/tmp/traktion-combined-goldens .build/x86_64-unknown-linux-gnu/release/TRAKTIONPackageTests.xctest
bash scripts/check-repository.sh
git diff --check
```

Results: build PASS; **112 XCTest tests, zero failures**; repository check PASS;
whitespace check PASS. The unmodified main and the default SwiftPM test runner
both reproduced a process-accounting crash in this environment. The supported
integrated compiler driver plus direct XCTest invocation avoided that host
problem without suppressing tests. CI keeps the normal verification scripts.

Task 0012 also verified 43 evaluation bundles under `--all-artifacts`, no
artifacts for a passing default evaluation, eight invalid/protected-output CLI
requests, and two deliberate failures through one shared XCTest helper. The
injected probes were removed before the final 112-test build. Task 0014
records the observed pre-fix failures, unchanged default-budget phone-scale
positive, exhaustive overlap oracle, and bounded unequal-height search.

The final combined release CLI also passed all **43/43** standard evaluation
cases with no failure bundles and zero false-safe, false-warning, wrong-failure,
or nondeterministic verdicts. `scripts/smoke.sh` passed the complete Linux PNG
path using a transient shell function that added the integrated-driver and
`-enable-testing` build flags; the repository script itself is unchanged.

## PR #15 review follow-up

The first complete Linux/macOS [CI run](https://github.com/VASEYDEV/TRAKTION/actions/runs/34285874626)
passed. A late review then identified that nondeterminism retention kept only
the first observation. The corrected evaluation path publishes both observations
under `run-1/` and `run-2/`, each with its own outcome, recovered order, timing,
assessment, and available image/joint evidence. Publication is atomic for the
whole case, including when writing the second run fails.

Four new regression tests cover differing pixels, recovered-order differences
with identical images/plans, reconstruction versus refusal in either order,
and second-run write failure cleanup. The complete updated release suite passed
**116 tests**, the standard corpus passed **43/43**, and all-artifact evaluation
retained all 43 deterministic cases with the existing layout. Independent review
reproduced the four new tests and cleared the fix. The PR requires another full
CI pass on the updated head before merge.
