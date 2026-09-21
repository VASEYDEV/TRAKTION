# TRAKTION Non-Destructive Editing Model

## Principle

The editor stores operations, not destructive bitmap copies. Original assets remain immutable references.

## Implemented operations

Capture reordering, seam selection inside proven overlap, draft apply/cancel,
and undo/redo are implemented. History uses validated plan snapshots, while
original captures remain immutable. Local save/open is described below.

## Broader planned operations

- choose preferred source in overlap
- cut internal range
- restore cut range
- trim top/bottom/left/right
- hide repeated fixed element
- keep one fixed element
- recalculate joint
- accept/clear warning

## Manual alignment

The first editor supports bounded pixel/joint inspection and seam nudges inside
proven overlap. Ghost overlay, difference/edge maps, a loupe, magnetic snapping
and broader alignment correction remain planned.

## Cuts

Planned internal cuts close the removed gap without modifying source files. Cuts
must remain reversible until export and separate explicit source deletion.

## Project persistence

Version 1 stores exact original PNG bytes, capture IDs/order/names, the automatic
reconstruction evidence and the final committed seam plan. Opening reruns the
shipping engine to validate the evidence, restores original/modified state and
starts empty undo/redo history. Inspector drafts are not saved. No source paths,
cached proxies, flattened bitmap, export settings or command history are required.
See [ADR-024](adr/ADR-024-local-project-container.md) for the wire contract and limits.
