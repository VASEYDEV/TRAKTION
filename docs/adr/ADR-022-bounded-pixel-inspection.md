# ADR-022: Bounded read-only pixel inspection

Status: Accepted

## Context
Task 0019 needs source-pixel and joint inspection without another full-resolution
CGImage/Data allocation for long reconstructed images. Original rasters and the
successful reconstruction already occupy most of the experimental workspace
raster budget. UI code must not re-register or alter source pixels.

## Decision
Use one fixed-size viewport, at most 1,024 × 1,024 RGBA display pixels. The native
view is at most 320 × 240 points and derives its integer raster dimensions from
SwiftUI's display scale. The displayed image uses those dimensions divided by
that same scale. Zoom means **display pixels per source pixel**; 100% is 1:1,
not one source pixel per UIKit point. Fit and magnification use deterministic
nearest-neighbor sampling; pixels beyond source bounds remain transparent.
Pan uses whole source-pixel origins. At an edge, align the last sampled source
coordinate so fractional zoom cannot hide the last row or column.

The serial inspection worker builds only this viewport and its CGImage, off the
main actor. There is one running request and one replaceable pending viewport;
no tile cache, full-source display copy, or queue of raster jobs. Source arrays
are immutable Swift values shared with the workspace. A generation token rejects
stale completions, including a worker that ignores cancellation. Dismiss/reset
clear inspection state. Replacement is blocked until a cancelled worker drains,
so old source storage cannot overlap an unaccounted new import.

Admission reserves 24 MiB: six maximum 4 MiB buffers for published/next RGBA and
CGData plus transient display-copy allowance. This is added to retained captures,
result, thumbnails, result preview and their existing display-copy reservations.
It is an owned-storage policy, **not** a hard process RSS, GPU, framework cache,
or physical-device memory guarantee. Admission can refuse inspection while
preserving the successful result and originals. No budget or core threshold is
increased by this task.

Joints are resolved by stable capture IDs and existing plan placements. The view
shows both filenames and IDs, confidence, overlap length, output seam boundary,
overlap seam offset and each original's seam row. Selecting result/first/second
original centers its own existing pixels around the same boundary. Coordinates
are zero-based; the following capture owns the output seam row and subsequent
rows until the next joint. No registration is rerun and no confidence is changed.

## Tradeoffs and verification
The viewport pans when a drag ends; accessible buttons provide page steps,
zoom, Fit, 1:1 and top/bottom navigation. This bounded read-only tool does not yet
provide continuous inertial scrolling, pinch gestures, editing or export.
The fixed viewport can leave unused horizontal space on larger screens.

Independent source-coordinate tests cover result and both original seam crops,
scaling, boundaries, cancellation, coalescing and admission. Native tests exercise
the actual display, navigation, orientation and larger-text controls. Linux
resource evidence is explicitly separate from Apple display and device evidence.
See the [task note](../notes/2026-09-16-native-inspection.md).

Platform contract: Apple's [displayScale documentation](https://developer.apple.com/documentation/swiftui/environmentvalues/displayscale)
and [DragGesture documentation](https://developer.apple.com/documentation/swiftui/draggesture).
