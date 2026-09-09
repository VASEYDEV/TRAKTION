# Task: Native pixel and joint inspection

Status: queued — next after task 0017.

## Goal
Let users inspect the reconstructed pixels and each proven joint before adding
editing, persistence, or export.

## Current behavior
Task 0017 imports actual PNG captures, confirms supplied order, and presents a
bounded preview plus joint confidence. The full reconstruction and captures are
retained, but users cannot zoom to source pixels or inspect seam evidence.

## Required behavior
- Add an accessible read-only inspection route from a successful result.
- Show full result dimensions, actual zoom scale, and a reachable 1:1 pixel view.
- Select a joint and identify its two original captures, overlap rows, seam
  position, and existing confidence. Render only existing deterministic pixels.
- Keep the main thread responsive and bound visible raster/tile allocations;
  do not build a full-resolution CGImage/Data copy of a long composite merely
  to pan a viewport. Account for retained captures/result and inspection buffers.
- Returning, resetting, or replacing captures must clear stale inspection state.
- Retain the same originals, full result, typed failures, and confidence values.

## Non-goals
Pixel correction, nudge/cut/trim, undo/redo, project format, export, automatic
ordering UI, semantic review, and production signing/distribution.

## Allowed scope
TraktionUI inspection state/views and a narrowly scoped deterministic crop/tile
adapter if needed, native routing, focused unit/UI tests, runbook and ADR.
Core registration thresholds and source pixels remain unchanged.

## Acceptance criteria
- [ ] Actual result and joint regions match independent source-coordinate crops.
- [ ] Pan/zoom and a 1:1 view work on a long synthetic result without an extra
      full-resolution display allocation; memory evidence states its scope.
- [ ] Joint selection maps stable capture IDs to visible names and exact seam
      coordinates/confidence without re-running or weakening registration.
- [ ] Reset/replacement/navigation cannot display stale results or tiles.
- [ ] Portrait, landscape, larger text, labels, and controls are exercised on
      the actual simulator target, with inspection evidence recorded honestly.
- [ ] Existing repository/core/Apple PNG/native gates and independent review pass.

## Evidence and ownership
Assign one implementation writer; independently review pixel coordinates,
resource ownership, main-thread responsiveness, and accessibility. Use genuine
synthetic PNG/source truth; keep private captures out of CI. Physical-device
memory and signing require the developer's actual team/device and are separate
from simulator evidence.
