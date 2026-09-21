# ADR 024: Versioned local project container

Status: accepted for task 0022 implementation.

## Decision

A `.traktion` file contains an eight-byte magic, a big-endian format version and
bounded JSON manifest length, the UTF-8 manifest, then each original PNG payload
in confirmed capture order. Payload lengths are declared in the manifest; no ZIP,
base64, directory paths, previews or raster copies are embedded. V1 preserves IDs,
sanitized source names, exact original PNG bytes, automatic registration evidence
and the final committed seam plan. Undo/redo starts empty after opening; modified
status remains relative to the preserved automatic plan.

Imported captures retain immutable encoded Data from the already validated owned
staging copies. They never reread the external original URL. Encoded retention has
a separate 128 MiB aggregate limit (64 MiB per capture), including old and incoming
workspaces during replacement. Data uses copy-on-write; writing streams each
payload without making a combined archive allocation. Owned raster admission
remains 256 MiB and includes old workspace, new sources, worst-case output,
thumbnails/display copies and bounded result previews. These are admission limits,
not claims about process resident memory or platform decoder internals.

Opening takes a coordinated read and stages bounded payloads in a private temporary
directory. Framing, schema, unique IDs, counts, lengths, image metadata/CRC,
aggregate resource limits and trailing bytes are checked before decoding. The
Core's `ProjectRestorer` reruns the shipping reconstruction engine on decoded
originals; its automatic plan must exactly equal the saved plan. The restored committed plan must retain all
placements/evidence and differ only in valid seam positions. Both plans are
validated together; sequential replay of final seams is prohibited.
The file adapter owns framing, resource admission and I/O, while this Core
contract owns evidence acceptance and returns the reconstructed result and
restored document. UI or future front ends do not duplicate validity policy.

Saving uses an explicit user-selected Files folder and a validated basename with
`.traktion` extension. A worker exclusively creates a private `0700` staging
directory in app-controlled temporary storage, outside Documents and the selected
folder, then streams and flushes an exclusive `0600` file inside it. Publication
runs under a cancellation commit lock. Every save uses an atomic no-clobber hard
link followed by removal of the owned private staging directory.
Any occupied destination is refused, including projects, unrelated files,
directories and symlinks. The user chooses a new filename. Precommit cancellation
or failure leaves no new destination; a successful commit is reported as saved
even if cancellation follows it. Original source URLs are never reused.

Review rejected the initial explicit-replacement path: file coordination cannot
exclude uncoordinated writers, and checking a file before `rename` does not bind
that rename to the validated object. V1 therefore never overwrites an existing
directory entry. No check/rename sequence or swap-and-rollback substitutes for
the atomic no-clobber guarantee.

A later review rejected sibling staging too: a writer in the selected folder
could replace that temporary pathname before `link` resolves its source. Private
staging removes that source from the selected-folder writer's namespace. This
boundary protects against access to the chosen folder, not a privileged process
that can modify app-private storage. Hard-link publication requires the same
filesystem; cross-filesystem or unsupported locations fail closed with guidance
to choose local storage. There is no copy fallback or return to sibling staging.

The workspace serial queue owns persistence operations. Job identity, cancellation
and draining protect publication; a failed or cancelled open preserves existing
work. Owned temporary cleanup failures are typed and remain visible even after
cancellation/reset. A postcommit cleanup failure explicitly says the project
was saved. Storage providers that do not support the required atomic filesystem
operation fail rather than falling back to a partial copy.

The native picker uses real Files UI. Documents is exposed for local Files
selection, while staging remains outside Documents. The app does not use network transport, a cloud service, a model API, an external
dependency or generated pixels. A Files provider may manage its own remote
storage; select TRAKTION under On My iPhone for the local offline path.

## Consequences

Opening requires deterministic reconstruction compatibility. V1 rejects evidence
that the current engine cannot reproduce rather than silently migrating it. A
future engine/format migration needs an explicit versioned contract. Saves include
committed seam positions only; an inspector draft is not a saveable state.

## Resource admission example

Ten 1170 × 2532 captures reserve 29,624,400 input pixels. Opening reserves
236,995,200 bytes for originals plus worst-case automatic output, 4,014,080 bytes
for thumbnails/display copies, and 8,388,608 bytes for bounded result preview and
display: **249,397,888 bytes**. The 268,435,456-byte limit leaves **19,037,568 bytes**
for an existing workspace; one additional retained byte is rejected before any
decoder runs. A previously retained 216,269,648-byte workspace therefore cannot
coexist with this incoming batch and must first be reset. Tests verify that exact
boundary using CRC-valid metadata and a decoder spy, without allocating ten
large rasters. This is admission arithmetic, not a process-RSS measurement.

The raw encoded PNG payloads remain independently bounded to 134,217,728 bytes
across old and incoming workspaces, with a 67,108,864-byte per-source cap. Platform
codec/transient framework allocations remain outside the owned-retention metric.
