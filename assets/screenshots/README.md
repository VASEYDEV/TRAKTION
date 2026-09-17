# Verified native screenshots

These are unchanged XCTest attachments from synthetic fixtures, not mockups or
private captures. Both PNGs were visually inspected before inclusion.

| File | Scenario | Evidence |
| --- | --- | --- |
| `reconstruction.png` | Native baseline PNG reconstruction, portrait | Debug `testImportedCapturesRequireConfirmedOrderAndReconstructInBothOrientations` |
| `joint-original.png` | Joint 2 original-source evidence, portrait | Release `testLongPixelInspectionPanZoomJointSourcesAndReturn` |

Source: [main CI run 35163939876](https://github.com/VASEYDEV/TRAKTION/actions/runs/35163939876),
commit `c279264e9d7e552561a7e52ec5368df17e99af84`, artifact
`traktion-ios-verification` (10474776045), iPhone SE (3rd generation), iOS 26.2.
These establish the task-0019 build; new editing controls are documented separately.
The source SVG logo masters remain in `assets/` with their original geometry.
