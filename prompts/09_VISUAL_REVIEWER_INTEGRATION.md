# Prompt: Add Provider-Neutral Semantic Review

This task occurs only after deterministic reconstruction and validation layers are established.

## Goal
Introduce an optional `VisualReviewer` capability without coupling the reconstruction engine to any provider.

## Requirements
- protocol/interface owned by `TraktionAI`
- disabled implementation
- deterministic mock implementation
- one production adapter behind configuration
- strict typed request/response
- minimized diagnostic payload
- no provider SDK types outside `TraktionAI`
- no final-pixel editing by the reviewer
- deterministic validation of any recommendation before application

## Trigger policy
Reviewer is called only for semantic ambiguity after local validation cannot resolve the case.

## Tests
Cover reviewer disabled, timeout/failure, abstention, invalid recommendation rejected, valid recommendation accepted only after deterministic validation, and no network path for exact/strong local reconstructions.

Do not add a second provider or consensus layer.
