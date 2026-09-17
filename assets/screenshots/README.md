# Verified native screenshots

These are unchanged XCTest attachments from synthetic fixtures, not mockups or
private captures. All three PNGs were visually inspected before inclusion.
They replace the older task-0019 gallery with the current editing build.

| File | Scenario | Passing XCTest |
| --- | --- | --- |
| `reconstruction.png` | Native baseline reconstruction and automatic-seam status | Debug `testImportedCapturesRequireConfirmedOrderAndReconstructInBothOrientations` |
| `joint-original.png` | Joint 2, second original's pixels | Release `testLongPixelInspectionPanZoomJointSourcesAndReturn` |
| `seam-adjustment.png` | Applied adjustment, modified result and undo history | Debug `testSeamAdjustmentCancelApplyUndoRedoAndReopen` |

Source: [successful CI run 35222997795](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795),
commit `1daafd6d013eb4af92d26b2c4061b22e8cb1e1e4`, artifact
[`traktion-ios-verification` (10498282851)](https://github.com/VASEYDEV/TRAKTION/actions/runs/35222997795/artifacts/10498282851),
iPhone SE (3rd generation), iOS 26.2, Xcode 16.4. All nine Debug and one Release
cases passed, including the source-inventory guards.

Landscape draft and XXXL seam-control attachments from this same run were also
visually reviewed; the original full artifact retains them. The concept artwork
and official SVG masters are documented separately in [assets](../README.md).
