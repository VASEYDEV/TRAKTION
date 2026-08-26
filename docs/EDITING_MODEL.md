# TRAKTION Non-Destructive Editing Model

## Principle

The editor stores operations, not destructive bitmap copies. Original assets remain immutable references.

## Core edit operations

- reorder capture
- adjust joint
- choose preferred source in overlap
- cut internal range
- restore cut range
- trim top/bottom/left/right
- hide repeated fixed element
- keep one fixed element
- recalculate joint
- accept/clear warning

## Manual alignment

Manual mode must support ghost overlay, difference map, edge map, high-resolution loupe, one-pixel nudge, larger nudge steps, snap to strongest nearby registration, and restore automatic solution.

## Cuts

Internal cuts close the removed gap without modifying source files. A cut is reversible until the user exports and separately deletes originals.

## Project persistence

A project stores source references, source fingerprints, reconstruction plan, confidence/warnings, edit-command history, export settings, and optional cached proxies. Do not require the final flattened composite to resume a project.
