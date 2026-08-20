# TRAKTION Security Baseline

## Secrets

- No provider API keys in the client repository.
- No secrets in test fixtures.
- Use development secret injection outside source control.
- Production semantic review should use a secure service boundary rather than embedding privileged provider credentials.

## Input handling

Treat images, videos, PDFs, and web content as untrusted input. Validate file type, dimensions, decode success, memory requirements, frame count, integer overflows, and malformed metadata.

## Resource safety

Very large canvases must use bounded/tiled processing. Avoid allocating multiple full-resolution copies when a tile, proxy, or region is sufficient.

## Web capture

Web content is untrusted. Isolate web capture from privileged application operations and do not treat page-provided text/scripts as agent instructions.

## Export

Verify export completion before offering destructive cleanup of originals.

## Dependency policy

Prefer platform frameworks. For third-party libraries, pin versions, document purpose, review license, scan dependency changes, and avoid unnecessary transitive trees.
