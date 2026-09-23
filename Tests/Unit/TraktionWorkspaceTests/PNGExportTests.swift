import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import TraktionVision
import XCTest

final class PNGExportTests: XCTestCase {
  func testAutomaticAndEveryEditedBoundaryUseExactOriginalRows() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (captures, plan) = try markedFixture()
    for first in 0...4 { for second in 0...4 where 4 + first < 8 + second {
      var document = try SeamEditingDocument(plan: plan, captures: captures)
      try document.apply(adjustment(plan, joint: 0, row: first))
      try document.apply(adjustment(plan, joint: 1, row: second))
      let snapshot = LocalProjectSnapshot(captures: captures, originalPlan: plan, committedPlan: document.plan)
      let url = try PNGExportStore().export(snapshot, folder: files.folder, name: "pixels \(first) \(second)", retainedRasterBytes: 1000)
      let actual = try PNGCodec.decodeOpaqueRGBA8(from: url)
      XCTAssertEqual(actual.width, 4); XCTAssertEqual(actual.height, 16)
      XCTAssertEqual(actual.pixels, oracle(captures, boundaries: [4 + first, 8 + second], origins: [0, 4, 8], width: 4, height: 16))
      XCTAssertEqual(document.plan, snapshot.committedPlan)
    } }
    let renderer = try PlannedRasterRenderer(plan: plan, captures: captures)
    for row in [-1, 16, Int.max] { XCTAssertThrowsError(try renderer.rgbaRow(row, isCancelled: { false })) }
    XCTAssertThrowsError(try renderer.rgbaRow(0, isCancelled: { true }))
  }

  func testLongCommittedOutputIsNotPreviewSampled() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let width = 257, height = 3000, step = 2000
    let captures = try (0..<2).map { index in
      let pixels: [UInt8] = (0..<height).flatMap { y in
        (0..<width).flatMap { x in [UInt8(index + 1), UInt8(truncatingIfNeeded: y), UInt8(truncatingIfNeeded: x), 255] }
      }
      return CaptureAsset(id: CaptureID("long-\(index)"), sourceName: "source.png",
        image: try RasterImage(width: width, height: height, pixels: pixels))
    }
    let plan = ReconstructionPlan(axis: .vertical, outputWidth: width, outputHeight: 5000,
      placements: captures.enumerated().map { CapturePlacement(captureID: $0.element.id,
        originY: $0.offset * step, width: width, height: height) },
      joints: [JointDiagnosis(precedingCaptureID: captures[0].id, followingCaptureID: captures[1].id,
        overlapRows: 1000, seamRowInOverlap: 501, outputSeamRow: 2501,
        normalizedMeanAbsoluteError: 0.001, changedPixelFraction: 0.001, confidence: .strong)])
    let snapshot = LocalProjectSnapshot(captures: captures, originalPlan: plan, committedPlan: plan)
    let url = try PNGExportStore().export(snapshot, folder: files.folder, name: "Long", retainedRasterBytes: 0)
    let image = try PNGCodec.decodeOpaqueRGBA8(from: url)
    XCTAssertEqual(image.width, width); XCTAssertEqual(image.height, 5000)
    var mismatch = false
    for y in 0..<5000 { for x in 0..<width {
      let offset = (y * width + x) * 4, index = y < 2501 ? 0 : 1
      if image.pixels[offset] != UInt8(index + 1)
        || image.pixels[offset + 1] != UInt8(truncatingIfNeeded: y - index * step)
        || image.pixels[offset + 2] != UInt8(truncatingIfNeeded: x)
        || image.pixels[offset + 3] != 255 { mismatch = true }
    } }
    XCTAssertFalse(mismatch, "Full-resolution source coordinates must survive beyond preview limits")
  }

  func testRealExactAndNearExactExportsAndNames() throws {
    for near in [false, true] {
      let files = try ProjectTestFiles(nearExact: near); defer { files.remove() }
      let (snapshot, result) = try files.snapshot()
      let url = try PNGExportStore().export(snapshot, folder: files.folder, name: "Automatic", retainedRasterBytes: 0)
      XCTAssertEqual(try PNGCodec.decodeOpaqueRGBA8(from: url), result.image)
    }
    XCTAssertEqual(try PNGExportStore.filename(" name "), "name.png")
    XCTAssertEqual(try PNGExportStore.filename(String(repeating: "𐐀", count: 62) + "abc").utf8.count, 255)
    for name in ["", "../name", "name.png", String(repeating: "𐐀", count: 63)] {
      XCTAssertThrowsError(try PNGExportStore.filename(name))
    }
  }

  func testCollisionRacesCancellationAndLateCommitTruth() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    let url = files.folder.appendingPathComponent("race.png")
    let marker = Data("existing".utf8)
    let racing = PNGExportStore(publisher: AtomicOutputPublisher(beforeCommit: { try marker.write(to: url) }))
    XCTAssertThrowsError(try racing.export(snapshot, folder: files.folder, name: "race", retainedRasterBytes: 0)) {
      XCTAssertEqual($0 as? PNGExportFailure, .destinationExists)
    }
    XCTAssertEqual(try Data(contentsOf: url), marker)
    let token = LocalProjectCancellation()
    let cancelled = PNGExportStore(publisher: AtomicOutputPublisher(beforeCommit: { token.cancel() }))
    XCTAssertThrowsError(try cancelled.export(snapshot, folder: files.folder, name: "cancelled", retainedRasterBytes: 0, cancellation: token)) {
      XCTAssertEqual($0 as? PNGExportFailure, .cancelled)
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("cancelled.png").path))
    let committed = LocalProjectCancellation()
    let late = PNGExportStore(publisher: AtomicOutputPublisher(afterCommit: { committed.cancel() }))
    let saved = try late.export(snapshot, folder: files.folder, name: "late", retainedRasterBytes: 0, cancellation: committed)
    XCTAssertTrue(committed.didCommit); XCTAssertFalse(committed.isCancelled)
    XCTAssertNoThrow(try PNGCodec.decodeOpaqueRGBA8(from: saved))
    let missing = files.folder.appendingPathComponent("missing.png")
    try FileManager.default.createSymbolicLink(at: missing, withDestinationURL: files.folder.appendingPathComponent("absent"))
    XCTAssertThrowsError(try PNGExportStore().export(snapshot, folder: files.folder, name: "missing", retainedRasterBytes: 0)) {
      XCTAssertEqual($0 as? PNGExportFailure, .destinationExists)
    }
  }

  func testWriteFailureBudgetAndCleanupHaveTruthfulPublicationState() throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, _) = try files.snapshot()
    XCTAssertThrowsError(try PNGExportStore(maximumWorkingBytes: 1).export(snapshot, folder: files.folder, name: "budget", retainedRasterBytes: 0)) {
      XCTAssertEqual($0 as? PNGExportFailure, .resourceLimit)
    }
    for saved in [false, true] {
      let publisher = AtomicOutputPublisher(beforeCommit: {
        if !saved { throw LocalProjectFailure.fileAccess }
      }, removeOwned: { url in
        // Remove the test's private copy, then simulate a cleanup error.
        try FileManager.default.removeItem(at: url)
        throw LocalProjectFailure.fileAccess
      })
      let token = LocalProjectCancellation()
      XCTAssertThrowsError(try PNGExportStore(publisher: publisher).export(snapshot, folder: files.folder,
        name: "cleanup \(saved)", retainedRasterBytes: 0, cancellation: token)) {
        XCTAssertEqual($0 as? PNGExportFailure, .cleanupFailed(saved: saved))
      }
      XCTAssertEqual(token.didCommit, saved)
      XCTAssertEqual(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("cleanup \(saved).png").path), saved)
    }
    let destination = files.folder.appendingPathComponent("partial.png")
    XCTAssertThrowsError(try AtomicOutputPublisher().publish(destination: destination, cancellation: .init()) { handle in
      try handle.write(contentsOf: Data([1, 2, 3]))
      throw LocalProjectFailure.fileAccess
    })
    XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("budget.png").path))
  }
}
