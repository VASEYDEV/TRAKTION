# Prompt: Build FixtureForge

Implement a deterministic fixture generator for TRAKTION.

## Goal
Generate known-source long canvases and slice them into overlapping captures with recorded ground truth.

## Required controls
- source canvas dimensions
- vertical/horizontal axis
- capture viewport size
- overlap amount or ratio
- capture count
- duplicate capture
- reversed capture order
- missing middle coverage
- fixed header simulation
- fixed footer simulation
- floating control
- scrollbar
- one-pixel offset
- compression/degradation mode

## Manifest
Every generated set must include source ID, axis, source dimensions, capture IDs, source origins, expected order, expected overlap, expected status, and optional source hash.

Given the same seed/configuration, FixtureForge must produce identical output. Do not make fixtures dependent on a cloud service or language model.
