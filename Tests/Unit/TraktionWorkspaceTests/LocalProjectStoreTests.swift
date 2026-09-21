import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import TraktionVision
import XCTest

final class LocalProjectStoreTests: XCTestCase {
  func testExactOriginalBytesOrderEvidenceAndEditedPixelsSurviveSourceDeletion() throws {
    let files = try ProjectTestFiles(nearExact: true)
    defer { files.remove() }
    // Import in reverse, then restore confirmed order without recreating IDs.
    let captures = try PNGImportService().importCaptures(from: files.sources.reversed()).reversed()
    let ordered = Array(captures)
    let bytes = try files.sources.map { try Data(contentsOf: $0) }
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: ordered))
    XCTAssertEqual(automatic.plan.joints[0].confidence, .strong)
    var document = try SeamEditingDocument(plan: automatic.plan, captures: ordered)
    try document.apply(adjustment(automatic.plan, joint: 0, row: 0))
    let expected = try PlannedRasterRenderer(plan: document.plan, captures: ordered)
      .renderPreview(width: 40, height: 40, isCancelled: { false })
    XCTAssertNotEqual(expected, automatic.image)
    let snapshot = LocalProjectSnapshot(captures: ordered, originalPlan: automatic.plan, committedPlan: document.plan)
    for url in files.sources { try FileManager.default.removeItem(at: url) }
    let url = try LocalProjectStore().save(snapshot, folder: files.folder, name: "Edited original bytes")
    let opened = try LocalProjectStore().open(url)
    XCTAssertEqual(opened.captures.map(\.originalPNG), bytes.map(Optional.some))
    XCTAssertEqual(opened.captures.map(\.id), ordered.map(\.id))
    XCTAssertEqual(opened.captures.map(\.sourceName), ordered.map(\.sourceName))
    XCTAssertEqual(opened.result, automatic)
    XCTAssertEqual(opened.document.originalPlan, automatic.plan)
    XCTAssertEqual(opened.document.plan, document.plan)
    XCTAssertTrue(opened.document.isModified)
    XCTAssertFalse(opened.document.canUndo)
    XCTAssertFalse(opened.document.canRedo)
    XCTAssertEqual(try PlannedRasterRenderer(plan: opened.document.plan, captures: opened.captures)
      .renderPreview(width: 40, height: 40, isCancelled: { false }), expected)
  }

  func testDirectRestoreAcceptsFinalSeamsThatCannotBeReplayedInOrder() throws {
    let (captures, automatic) = try markedFixture(step: 2)
    // Original output seams 5/7; final 8/10. Moving seam 1 first crosses seam 2.
    var editing = try SeamEditingDocument(plan: automatic, captures: captures)
    XCTAssertThrowsError(try editing.apply(adjustment(automatic, joint: 0, row: 6)))
    try editing.apply(adjustment(automatic, joint: 1, row: 6))
    try editing.apply(adjustment(automatic, joint: 0, row: 6))
    let restored = try SeamEditingDocument(originalPlan: automatic,
      committedPlan: editing.plan, captures: captures)
    XCTAssertTrue(restored.isModified)
    XCTAssertFalse(restored.canUndo)
    let result = try PlannedRasterRenderer(plan: restored.plan, captures: captures)
      .renderPreview(width: 4, height: 12, isCancelled: { false })
    XCTAssertEqual(result.pixels, oracle(captures, boundaries: [8, 10], origins: [0, 2, 4], width: 4, height: 12))
  }

  func testUnknownVersionTruncationTrailingBytesAndCorruptPNGAreRejected() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let store = LocalProjectStore()
    let url = try store.save(snapshot, folder: files.folder, name: "Malformed")
    let original = try Data(contentsOf: url)
    var unknown = original; unknown.replaceSubrange(8..<12, with: LocalProjectStore.uint32(2))
    try unknown.write(to: url)
    XCTAssertThrowsError(try store.open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .unsupportedVersion(2)) }
    var corrupt = original; corrupt[corrupt.count - 1] ^= 1
    for data in [Data(original.dropLast()), original + Data([0]), corrupt, Data([1, 2, 3])] {
      try data.write(to: url)
      XCTAssertThrowsError(try store.open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .invalidContainer) }
    }
  }

  func testMissingDuplicateIDsUnsafeNamesAndInvalidPlanMetadataAreRejected() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let url = try LocalProjectStore().save(snapshot, folder: files.folder, name: "References")
    let original = try Data(contentsOf: url)
    for change in 0..<4 {
      let data = try modifyingManifest(original) { manifest in
        var captures = manifest["captures"] as! [[String: Any]]
        switch change {
        case 0: captures.removeLast()
        case 1: captures[1]["id"] = captures[0]["id"]
        case 2: captures[0]["name"] = "../private.png"
        default: captures[0]["width"] = 0
        }
        manifest["captures"] = captures
      }
      try data.write(to: url)
      XCTAssertThrowsError(try LocalProjectStore().open(url))
    }
  }

  func testForgedAutomaticEvidenceAndCommittedRegistrationNeverLoad() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let url = try LocalProjectStore().save(snapshot, folder: files.folder, name: "Evidence")
    let original = try Data(contentsOf: url)
    for field in ["normalizedMeanAbsoluteError", "confidence", "overlapRows"] {
      let altered = try modifyingManifest(original) { manifest in
        var plan = manifest["automaticPlan"] as! [String: Any]
        var joints = plan["joints"] as! [[String: Any]]
        if field == "confidence" { joints[0][field] = "strong" }
        else if field == "overlapRows" { joints[0][field] = 1 }
        else { joints[0][field] = 0.0123 }
        plan["joints"] = joints; manifest["automaticPlan"] = plan
      }
      try altered.write(to: url)
      XCTAssertThrowsError(try LocalProjectStore().open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .invalidEvidence) }
    }
    let altered = try modifyingManifest(original) { manifest in
      var plan = manifest["committedPlan"] as! [String: Any]
      var placements = plan["placements"] as! [[String: Any]]
      placements[1]["originY"] = 0
      plan["placements"] = placements; manifest["committedPlan"] = plan
    }
    try altered.write(to: url)
    XCTAssertThrowsError(try LocalProjectStore().open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .invalidEvidence) }
  }

  func testAggregateEncodedRasterAndPixelAdmissionPrecedesEveryDecode() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let url = try LocalProjectStore().save(snapshot, folder: files.folder, name: "Admission")
    let spy = ProjectCounter()
    let store = LocalProjectStore(decode: { url in spy.increment(); return try PNGCodec.decodeOpaqueRGBA8(from: url) })
    for retained in [268_435_456, Int.max] {
      XCTAssertThrowsError(try store.open(url, retainedRasterBytes: retained)) {
        XCTAssertEqual($0 as? LocalProjectFailure, .resourceLimit)
      }
    }
    XCTAssertThrowsError(try store.open(url, retainedEncodedBytes: 134_217_728)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .resourceLimit)
    }
    let pixelStore = LocalProjectStore(limits: PNGImportLimits(maximumTotalInputPixels: 1), decode: { url in
      spy.increment(); return try PNGCodec.decodeOpaqueRGBA8(from: url)
    })
    XCTAssertThrowsError(try pixelStore.open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .resourceLimit) }
    XCTAssertEqual(spy.count, 0)
  }

  func testPhoneScaleHeaderAdmissionChecksOldAndNewWorkspaceBeforeDecoding() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("traktion-large-admission-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    // Structurally valid CRC-checked metadata, deliberately no compressed image:
    // the rejected path must never ask a decoder to allocate these phone rasters.
    let png = metadataOnlyPNG(width: 1170, height: 2532)
    let entries = (0..<10).map { LocalProjectStore.Entry(id: CaptureID("phone-\($0)"),
      name: "phone-\($0).png", byteCount: png.count, width: 1170, height: 2532) }
    let plan = ReconstructionPlan(axis: .vertical, outputWidth: 1170, outputHeight: 19020,
      placements: entries.enumerated().map { CapturePlacement(captureID: $0.element.id,
        originY: $0.offset * 1832, width: 1170, height: 2532) },
      joints: (0..<9).map { JointDiagnosis(precedingCaptureID: entries[$0].id,
        followingCaptureID: entries[$0 + 1].id, overlapRows: 700, seamRowInOverlap: 350,
        outputSeamRow: ($0 + 1) * 1832 + 350, normalizedMeanAbsoluteError: 0,
        changedPixelFraction: 0, confidence: .exact) })
    let manifest = try JSONEncoder().encode(LocalProjectStore.Manifest(captures: entries,
      automaticPlan: plan, committedPlan: plan))
    var container = LocalProjectStore.magic + LocalProjectStore.uint32(1)
      + LocalProjectStore.uint32(UInt32(manifest.count)) + manifest
    for _ in 0..<10 { container.append(png) }
    let url = folder.appendingPathComponent("phone.traktion")
    try container.write(to: url)
    let spy = ProjectCounter()
    let store = LocalProjectStore(decode: { _ in spy.increment(); throw LocalProjectFailure.invalidContainer })
    // 236,995,200 sources/worst-case output + 4,014,080 thumbnail copies +
    // 8,388,608 result preview copies = 249,397,888 owned bytes. Not process RSS.
    for retained in [19_037_569, 216_269_648] {
      XCTAssertThrowsError(try store.open(url, retainedRasterBytes: retained)) {
        XCTAssertEqual($0 as? LocalProjectFailure, .resourceLimit)
      }
    }
    XCTAssertEqual(spy.count, 0)
    // Exactly at the 256MiB admission boundary, preflight reaches the deliberately
    // failing decoder. This does not claim that metadata-only PNGs can be opened.
    XCTAssertThrowsError(try store.open(url, retainedRasterBytes: 19_037_568)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .invalidContainer)
    }
    XCTAssertEqual(spy.count, 1)
  }

  func testFailedAndPrecommitCancelledReplacementPreserveDestinationExactly() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let url = try LocalProjectStore().save(snapshot, folder: files.folder, name: "Atomic")
    let bytes = try Data(contentsOf: url)
    let token = LocalProjectCancellation()
    let cancelledStore = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), beforeCommit: { token.cancel() })
    XCTAssertThrowsError(try cancelledStore.save(snapshot, folder: files.folder, name: "Atomic", replacing: true, cancellation: token)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .cancelled)
    }
    XCTAssertFalse(token.didCommit)
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    let failingStore = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), beforeCommit: { throw LocalProjectFailure.fileAccess })
    XCTAssertThrowsError(try failingStore.save(snapshot, folder: files.folder, name: "Atomic", replacing: true))
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: files.folder.path).contains { $0.hasPrefix(".traktion-save-") })
  }

  func testPostcommitCancellationReportsSavedAndNewSaveCannotClobberAnInterveningFile() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let token = LocalProjectCancellation()
    let store = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), afterCommit: { token.cancel() })
    let url = try store.save(snapshot, folder: files.folder, name: "Committed", cancellation: token)
    XCTAssertTrue(token.didCommit)
    XCTAssertFalse(token.isCancelled)
    XCTAssertEqual(try store.open(url).result.plan, snapshot.originalPlan)
    let race = files.folder.appendingPathComponent("Racing.traktion")
    let unrelated = Data("not a project".utf8)
    let racingStore = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), beforeCommit: { try unrelated.write(to: race) })
    XCTAssertThrowsError(try racingStore.save(snapshot, folder: files.folder, name: "Racing")) {
      XCTAssertEqual($0 as? LocalProjectFailure, .destinationExists)
    }
    XCTAssertEqual(try Data(contentsOf: race), unrelated)
  }

  func testUnsafeReplacementAndNamesNeverOverwriteOriginalOrFollowSymlinks() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let target = files.folder.appendingPathComponent("Original.traktion")
    let original = try Data(contentsOf: files.sources[0]); try original.write(to: target)
    XCTAssertThrowsError(try LocalProjectStore().save(snapshot, folder: files.folder, name: "Original", replacing: true)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .unsafeReplacement)
    }
    XCTAssertEqual(try Data(contentsOf: target), original)
    let link = files.folder.appendingPathComponent("Link.traktion")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: files.folder.appendingPathComponent("absent"))
    XCTAssertThrowsError(try LocalProjectStore().save(snapshot, folder: files.folder, name: "Link", replacing: true)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .unsafeReplacement)
    }
    for name in ["", "../escape", "image.png", "a/b", "a\\b", String(repeating: "x", count: 81)] {
      XCTAssertThrowsError(try LocalProjectStore().save(snapshot, folder: files.folder, name: name)) {
        XCTAssertEqual($0 as? LocalProjectFailure, .invalidName)
      }
    }
  }

  func testCleanupFailureIsVisibleBeforeAndAfterCommitAndOnOpen() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let leftovers = ProjectPaths()
    let cannotRemove: @Sendable (URL) throws -> Void = { url in
      leftovers.append(url); throw LocalProjectFailure.fileAccess
    }
    defer { for url in leftovers.values { try? FileManager.default.removeItem(at: url) } }
    let token = LocalProjectCancellation()
    let cancelledStore = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), beforeCommit: { token.cancel() }, removeOwned: cannotRemove)
    XCTAssertThrowsError(try cancelledStore.save(snapshot, folder: files.folder, name: "Cleanup cancelled", cancellation: token)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .cleanupFailed(saved: false))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("Cleanup cancelled.traktion").path))
    let committedToken = LocalProjectCancellation()
    let store = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), removeOwned: cannotRemove)
    XCTAssertThrowsError(try store.save(snapshot, folder: files.folder, name: "Cleanup committed", cancellation: committedToken)) {
      XCTAssertEqual($0 as? LocalProjectFailure, .cleanupFailed(saved: true))
    }
    XCTAssertTrue(committedToken.didCommit)
    let url = files.folder.appendingPathComponent("Cleanup committed.traktion")
    XCTAssertEqual(try LocalProjectStore().open(url).result.plan, snapshot.originalPlan)
    XCTAssertThrowsError(try store.open(url)) { XCTAssertEqual($0 as? LocalProjectFailure, .cleanupFailed(saved: false)) }
  }
}

struct ProjectTestFiles {
  let folder: URL
  let sources: [URL]
  init(nearExact: Bool = false) throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent("traktion-project-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    let images: [RasterImage]
    if nearExact {
      let source = try SyntheticFixtureFactory.document(width: 40, height: 40, seed: 0x53414D50)
      var second = Array(source.pixels[10 * 160..<40 * 160]); second[0] ^= 1
      images = [try RasterImage(width: 40, height: 30, pixels: Array(source.pixels[0..<30 * 160])),
        try RasterImage(width: 40, height: 30, pixels: second)]
    } else { images = try SyntheticFixtureFactory.baseline().captures.map(\.image) }
    let directory = folder
    sources = images.indices.map { directory.appendingPathComponent("original-\($0).png") }
    for (image, url) in zip(images, sources) { try PNGCodec.encodeOpaqueRGBA8(image, to: url) }
  }
  func snapshot() throws -> (LocalProjectSnapshot, ReconstructionResult) {
    let captures = try PNGImportService().importCaptures(from: sources)
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    return (LocalProjectSnapshot(captures: captures, originalPlan: result.plan, committedPlan: result.plan), result)
  }
  func remove() { try? FileManager.default.removeItem(at: folder) }
}

private func modifyingManifest(_ container: Data, body: (inout [String: Any]) -> Void) throws -> Data {
  let length = LocalProjectStore.integer(container, offset: 12)
  var manifest = try JSONSerialization.jsonObject(with: container.subdata(in: 16..<16 + length)) as! [String: Any]
  body(&manifest)
  let bytes = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
  return LocalProjectStore.magic + LocalProjectStore.uint32(1) + LocalProjectStore.uint32(UInt32(bytes.count))
    + bytes + container.suffix(from: 16 + length)
}

final class ProjectCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  var count: Int { lock.withLock { value } }
  func increment() { lock.withLock { value += 1 } }
}
private final class ProjectPaths: @unchecked Sendable {
  private let lock = NSLock()
  private var paths: [URL] = []
  var values: [URL] { lock.withLock { paths } }
  func append(_ url: URL) { lock.withLock { paths.append(url) } }
}

private func metadataOnlyPNG(width: UInt32, height: UInt32) -> Data {
  func chunk(_ name: String, _ payload: Data) -> Data {
    let body = Data(name.utf8) + payload
    var crc: UInt32 = 0xffff_ffff
    for byte in body {
      crc ^= UInt32(byte)
      for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1 }
    }
    return LocalProjectStore.uint32(UInt32(payload.count)) + body + LocalProjectStore.uint32(crc ^ 0xffff_ffff)
  }
  return Data([137, 80, 78, 71, 13, 10, 26, 10])
    + chunk("IHDR", LocalProjectStore.uint32(width) + LocalProjectStore.uint32(height) + Data([8, 6, 0, 0, 0]))
    + chunk("IDAT", Data()) + chunk("IEND", Data())
}
