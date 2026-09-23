# ADR-025: Bounded committed-result PNG export

Status: accepted for task 0023 implementation.

Export snapshots the committed seam document and immutable captures. Core supplies
one exact integer RGBA row at a time; preview sampling and the automatic composite
are not export authorities. Vision accepts rows through a closure, without a Core
dependency. It emits filter-zero RGBA PNG with stored DEFLATE blocks in one zlib
stream, incremental Adler-32 and bounded CRC-protected IDAT chunks.

Admission precedes row reads and writes: output is limited to 67,108,864 pixels
(the Core output limit), each row to 1 MiB, encoded output to 300 MiB. Checked
arithmetic covers dimensions, filtered bytes, block/chunk framing and workspace
plus scratch memory. Scratch reserves three row buffers plus 1 MiB for bounded
block/chunk copies. Existing capture decoding remains limited to 16,777,216 pixels;
large-output verification uses a separate test-only decoder allowance.

The workspace serial worker stays occupied until export drains after cancellation
or reset. Export excludes drafts and rendering, closes inspection, and snapshots
once. Publication uses a private app temporary file and atomic no-clobber hard link
under the same cancellation/commit lock as project saving. Existing files, symlinks
and unsupported cross-filesystem providers are refused. There is no copy fallback
or overwrite mode. A committed export remains reported as saved even after reset
or late cancellation; cleanup failure distinguishes committed from uncommitted.

Stored blocks favor bounded, independently verifiable encoding over compression.
Files can be large; PDF, compressed codecs, sharing and overwrite remain separate work.
