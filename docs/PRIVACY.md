# TRAKTION Privacy Principles

Screenshots and screen recordings may contain sensitive data.

## Defaults

- Core reconstruction is local.
- Source files are not uploaded by default.
- Semantic review is optional.
- Remote requests contain the minimum diagnostic evidence required.
- Original assets remain on-device unless explicitly exported/shared.
- Deletion of originals requires explicit user action after successful export.

## Remote semantic review

Prefer disputed crops instead of the full image, downsampled contact sheets, locally generated OCR/measurements, and metadata stripping.

## Logging

Do not log raw source pixels, OCR text, or sensitive user content in analytics. Diagnostic logging should use hashed asset IDs, dimensions, numeric confidence values, error codes, and performance timing.

## Test fixtures

Real-world captures are private by default and must not be committed unless sanitized and deliberately approved. Synthetic fixtures should be preferred for repository tests.
