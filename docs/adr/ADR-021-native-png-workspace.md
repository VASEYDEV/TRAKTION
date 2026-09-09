# ADR-021: Atomic PNG import and a serial native workspace

Status: Accepted
Date: 2026-09-09
Task: 0017

## Context
The iOS target can launch, but users need to import their actual captures and
reconstruct them through the verified engine. External files, hostile headers,
large rasters, and cancellation create ownership and resource risks that the
read-only shell did not have. The synchronous engine cannot cooperatively stop.

## Decision
`PNGImportService` in TraktionVision admits one batch of 2–10 regular files.
It opens original URLs read-only; on Apple platforms it balances successful
security-scoped access and copies inside the synchronous coordinated-read
accessor. Each invocation owns a unique private temporary directory. It copies
in bounded blocks, never replaces an original, and removes only its own copies
before returning. A failed or cancelled batch never publishes partial captures.
Cleanup failure is typed and remains visible even after cancellation or reset.

Preflight reads the entire bounded encoded stream without decoding a raster.
It verifies PNG signature, chunk framing/CRCs, IHDR, static content, IEND, and
absence of trailing bytes; animation markers anywhere in the stream fail.
Widths, per-image dimensions, aggregate pixels/encoded bytes, and retained
workspace bytes pass overflow-checked admission before the first decode.
The shipping codec then decodes sequentially, verifies opacity, and must agree
with the inspected dimensions. Capture IDs are unique and independent of file
names or list positions. Display names exclude control characters.

Preflight cannot safely bound a codec that expands compressed data beyond its
header. The pure-Swift PNG decoder now derives the checked filtered-byte length
from IHDR and passes it into zlib inflation. Literal, stored-block, and match
appends reject excess growth before allocation. Valid PNG output is unchanged;
no core reconstruction algorithm or threshold changes.

`NativeWorkspaceModel` owns observable MainActor state and one serial background
queue per workspace. File reading, decoding, the unchanged supplied-order
vertical engine, and preview sampling run there. The UI requires explicit
confirmation of top-to-bottom order. Move/remove preserve capture identity and
invalidate confirmation and the old result. No automatic ordering is implied.

An operation retains its request ID and locked cancellation token until its
synchronous worker actually returns. Cancel suppresses publication, while reset
also clears visible state. Neither admits a replacement operation early.
Cancelled completion cannot revive a cleared workspace; failed/cancelled
replacement preserves the previous captures, result, and confirmation. Resource
cleanup errors remain visible because they can mean owned temporary copies remain.

Successful output is the engine's actual raster, dimensions, and joint confidence.
Failures retain the existing typed payload and map IDs to numbered source names.
No missing coverage is fabricated or converted into success. Display previews
sample source pixels on the worker: thumbnails have a maximum 224-pixel edge;
result previews have at most 1,048,576 pixels and a 4,096-pixel edge. The originals
and full result stay intact. SwiftUI makes only bounded CGImage display copies
and labels the result as a preview. This is not a pixel-scale inspection tool.

## Resource accounting
Initial admission ceilings are 16,777,216 pixels per image (existing codec),
33,554,432 aggregate input pixels, 64 MiB per encoded file, 128 MiB total encoded
files, and 256 MiB for the workspace raster reservation. Limits are explicit and
injectable in tests. These are experimental admission ceilings, not a device
memory guarantee or an adaptive physical-device policy.

Replacement admission includes old captures, old output, thumbnails/result
preview, and one bounded CGImage copy per preview. After input decode but before
any new thumbnail allocation, the model checks actual incoming raster bytes
plus exactly projected thumbnail bytes and their display-copy reservation.
Reconstruction reserves inputs, existing thumbnails/display copies, worst-case
vertical output (the sum of input areas), and a bounded result/display preview.
Counting shared small previews separately is deliberately conservative.

Encoded buffers, decode scratch space, allocator retention, SwiftUI/framework
internals, and image-provider allocations can raise process RSS beyond that
reservation. Cancellation does not immediately release worker memory. Actual
fresh-process import/reconstruction measurements and their reproducible probes
are recorded in the [evidence note](../notes/2026-09-09-native-png-workflow.md);
Linux measurements do not establish
Apple ImageIO, simulator, or physical-device peaks.

## Verification and remaining scope
Portable tests cover whole-batch admission, original byte integrity, owned-copy
cleanup, hostile compressed expansion, stable order, exact source reconstruction,
typed duplicate/gap/directional refusals, bounded previews, single-worker
admission, and cancellation/reset draining. Simulator tests import genuine
FixtureForge PNGs through the production service, exercise confirmation,
reordering, success/failure/reset, rotation and larger text, and separately
present/cancel the actual Files picker. Debug fixture injection never bypasses
the importer or engine and is absent from release builds.

No shipping dependencies, network service, automatic ordering UI, Photos
transcoding, editor, undo/redo, persistence, export, production artwork, or
physical-device distribution is added. Private screenshots are not CI fixtures.

## References
- [Apple: Security-scoped URL access](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource())
- [Apple: Coordinated file reading](https://developer.apple.com/documentation/foundation/nsfilecoordinator/coordinate(readingitemat:options:error:byaccessor:))
- [W3C: PNG specification](https://www.w3.org/TR/png-3/)
- [ADR-011: PNG boundary](ADR-011-imageio-boundary-pure-swift-fallback.md)
- [ADR-020: Native target](ADR-020-native-ios-target.md)
