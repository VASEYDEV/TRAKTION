# Verified native screenshots

These are unchanged XCTest attachments from synthetic fixtures, not mockups or
private captures. Every included PNG was visually inspected before inclusion.
The editing captures remain useful evidence; the project captures add the verified
local save/open workflow.

| File | Scenario | Passing XCTest |
| --- | --- | --- |
| `reconstruction.png` | Native baseline reconstruction and automatic-seam status | Debug `testImportedCapturesRequireConfirmedOrderAndReconstructInBothOrientations` |
| `joint-original.png` | Joint 2, second original's pixels | Release `testLongPixelInspectionPanZoomJointSourcesAndReturn` |
| `seam-adjustment.png` | Applied adjustment, modified result and undo history | Debug `testSeamAdjustmentCancelApplyUndoRedoAndReopen` |

Editing source: [successful CI run 35222997795](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795),
commit `1daafd6d013eb4af92d26b2c4061b22e8cb1e1e4`, artifact
[`traktion-ios-verification` (10498282851)](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795/artifacts/10498282851),
iPhone SE (3rd generation), iOS 26.2, Xcode 16.4. All nine Debug and one Release
cases passed, including the source-inventory guards.

Landscape draft and XXXL seam-control attachments from this same run were also
visually reviewed; the original full artifact retains them. The concept artwork
and official SVG masters are documented separately in [assets](../README.md).

## Local projects — 2026-09-21

| File | Scenario | Passing XCTest |
| --- | --- | --- |
| `local-project.png` | Actual local project reopened after a refused overwrite and empty relaunch | Debug `testExistingProjectNameRefusesOverwriteAndPreservesSavedFile` |
| `local-project-seam.png` | Reopened automatic overlap 24, committed output/overlap 137/25, modified status and fresh history | Debug `testEditedProjectSavesThroughFilesAndReopensAfterEmptyLaunch` |

Source: [successful CI run 35569321865](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865),
commit `5821eac039b9e182bc465572e32090aaf40c08e7`, artifact
[`traktion-ios-verification` (10626196524)](https://github.com/VASEYDEV/TRAKTION/actions/runs/35569321865/artifacts/10626196524),
iPhone SE (3rd generation), iOS 26.2, Xcode 16.4 (16F6). All 13 Debug cases and
one full-phone Release case passed, as did both inventory guards, with no timeout
or restart. The ZIP SHA-256 was verified before extracting the attachments.

Unchanged source members under `run.pv1KYi/attachments/debug/`:

- `ADD83849-C0C5-4962-B036-D380ACF500ED.png` → `local-project.png`.
- `C4885E61-6549-464C-8778-C2EA1D4BD3F6.png` → `local-project-seam.png`.

XXXL project controls and corrupt-project refusal screenshots from the same
successful run were also visually inspected; the full artifact retains them.
These images establish simulator behavior, not physical-device or provider readiness.
