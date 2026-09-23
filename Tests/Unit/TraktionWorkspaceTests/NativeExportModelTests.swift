import Foundation
import TraktionCore
@testable import TraktionUI
import TraktionVision
import XCTest

@MainActor
final class NativeExportModelTests: XCTestCase, @unchecked Sendable {
  func testCommittedSnapshotDraftGuardAndHistoryPreservation() async throws {
    let files = try ProjectTestFiles(nearExact: true); defer { files.remove() }
    let model = NativeWorkspaceModel()
    try await prepare(model, files)
    model.inspection.editing.admit(retainedBytes: 0, budget: 268_435_456)
    model.inspection.editing.begin(joint: 0)
    XCTAssertFalse(model.canExportPNG)
    model.exportPNG(folder: files.folder, name: "Draft")
    XCTAssertNil(model.operation)
    model.inspection.editing.setSeam(0)
    model.inspection.editing.apply()
    XCTAssertFalse(model.canExportPNG)
    try await until { !model.isBusy }
    let document = try XCTUnwrap(model.inspection.editing.document)
    let originals = model.captures
    model.exportPNG(folder: files.folder, name: "Committed")
    try await until { !model.isBusy }
    XCTAssertNil(model.failure)
    XCTAssertEqual(model.projectMessage, "Exported Committed.png.")
    let actual = try PNGCodec.decodeOpaqueRGBA8(from: files.folder.appendingPathComponent("Committed.png"))
    let renderer = try PlannedRasterRenderer(plan: document.plan, captures: originals)
    for y in 0..<actual.height {
      XCTAssertEqual(Array(actual.pixels[y * actual.rowByteCount..<(y + 1) * actual.rowByteCount]),
        try renderer.rgbaRow(y, isCancelled: { false }))
    }
    XCTAssertNotEqual(actual, model.result?.image)
    XCTAssertEqual(model.captures, originals)
    XCTAssertEqual(model.inspection.editing.document?.plan, document.plan)
    XCTAssertTrue(model.inspection.editing.canUndo)
  }

  func testResetAndCancellationDrainWorkerAndLateCommitRemainsTruthful() async throws {
    for afterCommit in [false, true] {
      let files = try ProjectTestFiles(); defer { files.remove() }
      let gate = ExportBlockingGate(); defer { gate.release() }
      let publisher = afterCommit
        ? AtomicOutputPublisher(afterCommit: { gate.wait() })
        : AtomicOutputPublisher(beforeCommit: { gate.wait() })
      let model = NativeWorkspaceModel(exports: PNGExportStore(publisher: publisher))
      try await prepare(model, files)
      model.exportPNG(folder: files.folder, name: "Reset")
      try await until { gate.entered.count == 1 }
      XCTAssertEqual(model.operation, .exportingPNG)
      model.reset()
      model.importCaptures(from: files.sources)
      model.exportPNG(folder: files.folder, name: "Overlapping")
      XCTAssertTrue(model.isBusy)
      XCTAssertTrue(model.captures.isEmpty)
      gate.release()
      try await until { !model.isBusy }
      XCTAssertNil(model.result)
      XCTAssertEqual(model.projectMessage, afterCommit ? "Exported Reset.png." : nil)
      XCTAssertEqual(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("Reset.png").path), afterCommit)
      XCTAssertFalse(FileManager.default.fileExists(atPath: files.folder.appendingPathComponent("Overlapping.png").path))
    }
  }

  private func prepare(_ model: NativeWorkspaceModel, _ files: ProjectTestFiles) async throws {
    model.importCaptures(from: files.sources)
    try await until { !model.isBusy }
    model.confirmOrder(); model.reconstruct()
    try await until { !model.isBusy }
    XCTAssertNotNil(model.result)
  }
  private func until(_ condition: @MainActor () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(10)
    while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertTrue(condition())
  }
}

private final class ExportBlockingGate: @unchecked Sendable {
  let entered = ProjectCounter()
  private let semaphore = DispatchSemaphore(value: 0)
  func wait() { entered.increment(); _ = semaphore.wait(timeout: .now() + 10) }
  func release() { semaphore.signal() }
}
