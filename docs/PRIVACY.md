# TRAKTION Privacy Principles

Screenshots and screen recordings may contain sensitive data.

## Defaults

- Core reconstruction is local.
- Source files are not uploaded by default.
- Semantic review is optional.
- Remote requests contain the minimum diagnostic evidence required.
- Working copies stay within the local workspace unless the user deliberately saves
  a project or uses an export/share capability.
- Deletion of originals requires explicit user action after successful export.

## Remote semantic review

Prefer disputed crops instead of the full image, downsampled contact sheets, locally generated OCR/measurements, and metadata stripping.

## Local projects

A `.traktion` project embeds exact original PNG bytes, including their metadata,
source basenames, confirmed order and reconstruction/seam evidence. Treat the
project as containing the same sensitive material as its captures. The app adds
no external source URLs, app credentials or model request records; sensitive
information already present in original pixels or PNG metadata is preserved.

TRAKTION makes no network/model request during save/open. The selected Files
provider may synchronize its own storage independently; choose **On My iPhone →
TRAKTION** for local storage. User-saved projects are visible in Files. Private
import/open staging and synthetic input fixtures stay outside shared Documents.
Owned staging is removed on completion or cancellation; cleanup failures are
reported rather than silently claiming the private copies were removed.

## Logging

Do not log raw source pixels, OCR text, or sensitive user content in analytics. Diagnostic logging should use hashed asset IDs, dimensions, numeric confidence values, error codes, and performance timing.

## Test fixtures

Real-world captures are private by default and must not be committed unless sanitized and deliberately approved. Synthetic fixtures should be preferred for repository tests.
