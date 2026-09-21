import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import TraktionVision
import XCTest

@MainActor
final class NativeProjectModelTests: XCTestCase, @unchecked Sendable {
  func testModelSavesCommittedEditsAndOpensWithFreshHistory() async throws {
    let files = try ProjectTestFiles(nearExact: true); defer { files.remove() }
    let model = NativeWorkspaceModel()
    try await prepare(model, files: files)
    let automatic = try XCTUnwrap(model.result)
    model.inspection.editing.admit(retainedBytes: 0, budget: 268_435_456)
    model.inspection.editing.begin(joint: 0)
    XCTAssertFalse(model.canSaveProject)
    model.inspection.editing.setSeam(0)
    model.inspection.editing.apply()
    try await until { !model.isBusy }
    XCTAssertTrue(model.isModified)
    let edited = model.resultPreview
    let sources = model.captures
    model.saveProject(folder: files.folder, name: "Model roundtrip")
    try await until { !model.isBusy }
    XCTAssertTrue(model.projectMessage?.contains("Saved Model roundtrip.traktion") == true)
    model.reset()
    XCTAssertNil(model.result)
    model.openProject(files.folder.appendingPathComponent("Model roundtrip.traktion"))
    try await until { !model.isBusy }
    XCTAssertEqual(model.captures, sources)
    XCTAssertEqual(model.result, automatic)
    XCTAssertEqual(model.resultPreview, edited)
    XCTAssertTrue(model.isModified)
    XCTAssertTrue(model.orderConfirmed)
    XCTAssertFalse(model.inspection.editing.canUndo)
    XCTAssertFalse(model.inspection.editing.canRedo)
    XCTAssertTrue(model.canSaveProject)
    let oldPlan = model.inspection.editing.document?.plan
    model.openProject(files.sources[0])
    try await until { !model.isBusy }
    XCTAssertEqual(model.failure, .project(.invalidContainer))
    XCTAssertEqual(model.captures, sources)
    XCTAssertEqual(model.resultPreview, edited)
    XCTAssertEqual(model.inspection.editing.document?.plan, oldPlan)
  }

  func testCancelledAndResetOpenDrainBeforeNewWorkAndNeverPublishStaleResults() async throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, result) = try files.snapshot()
    let loaded = LoadedLocalProject(captures: snapshot.captures, result: result,
      document: try SeamEditingDocument(plan: result.plan, captures: snapshot.captures))
    let blocked = BlockingProjectWorker(loaded: loaded)
    defer { blocked.release() }
    let model = NativeWorkspaceModel(projects: blocked)
    try await prepare(model, files: files)
    let oldCaptures = model.captures
    let oldResult = model.result
    let oldPreview = model.resultPreview
    model.openProject(files.folder.appendingPathComponent("any.traktion"))
    try await until { blocked.calls.count == 1 }
    XCTAssertEqual(model.operation, .openingProject)
    XCTAssertGreaterThan(blocked.retainedRaster, 0)
    XCTAssertGreaterThan(blocked.retainedEncoded, 0)
    model.cancel()
    model.openProject(files.folder)
    model.importCaptures(from: files.sources)
    XCTAssertTrue(model.isBusy)
    XCTAssertTrue(model.isCancelling)
    XCTAssertEqual(blocked.calls.count, 1)
    blocked.release()
    try await until { !model.isBusy }
    XCTAssertEqual(model.captures, oldCaptures)
    XCTAssertEqual(model.result, oldResult)
    XCTAssertEqual(model.resultPreview, oldPreview)
    XCTAssertNil(model.failure)
    model.openProject(files.folder)
    try await until { blocked.calls.count == 2 }
    model.reset()
    model.openProject(files.folder)
    XCTAssertTrue(model.isBusy)
    XCTAssertTrue(model.captures.isEmpty)
    blocked.release()
    try await until { !model.isBusy }
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertNil(model.projectMessage)
  }

  func testResetAfterAtomicCommitKeepsSavedReceiptAndEmptyWorkspace() async throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let gate = ProjectBlockingGate()
    defer { gate.release() }
    let store = LocalProjectStore(decode: PNGCodec.decodeOpaqueRGBA8(from:), afterCommit: { gate.wait() })
    let model = NativeWorkspaceModel(projects: store)
    try await prepare(model, files: files)
    model.saveProject(folder: files.folder, name: "Committed before reset")
    try await until { gate.entered.count == 1 }
    model.reset()
    XCTAssertTrue(model.isBusy)
    XCTAssertTrue(model.captures.isEmpty)
    gate.release()
    try await until { !model.isBusy }
    XCTAssertNil(model.result)
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertTrue(model.projectMessage?.contains("Saved Committed before reset.traktion") == true)
    let opened = try LocalProjectStore().open(files.folder.appendingPathComponent("Committed before reset.traktion"))
    XCTAssertEqual(opened.captures.count, 3)
  }

  func testCancelledOpenCleanupFailureRemainsVisibleAfterReset() async throws {
    let files = try ProjectTestFiles(); defer { files.remove() }
    let (snapshot, result) = try files.snapshot()
    let worker = BlockingProjectWorker(loaded: LoadedLocalProject(captures: snapshot.captures,
      result: result, document: try SeamEditingDocument(plan: result.plan, captures: snapshot.captures)),
      failure: .cleanupFailed(saved: false))
    defer { worker.release() }
    let model = NativeWorkspaceModel(projects: worker)
    model.openProject(files.folder)
    try await until { worker.calls.count == 1 }
    model.reset()
    worker.release()
    try await until { !model.isBusy }
    XCTAssertEqual(model.failure, .project(.cleanupFailed(saved: false)))
    XCTAssertTrue(model.captures.isEmpty)
  }

  private func prepare(_ model: NativeWorkspaceModel, files: ProjectTestFiles) async throws {
    model.importCaptures(from: files.sources)
    try await until { !model.isBusy }
    XCTAssertNil(model.failure)
    model.confirmOrder()
    model.reconstruct()
    try await until { !model.isBusy }
    XCTAssertNotNil(model.result)
  }
  private func until(_ condition: @MainActor () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(10)
    while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertTrue(condition(), "Workspace operation did not reach its expected state")
  }
}

private final class BlockingProjectWorker: LocalProjectWorking, @unchecked Sendable {
  let calls = ProjectCounter()
  private let gate = DispatchSemaphore(value: 0)
  private let loaded: LoadedLocalProject
  private let failure: LocalProjectFailure?
  private let lock = NSLock()
  private var raster = 0
  private var encoded = 0
  var retainedRaster: Int { lock.withLock { raster } }
  var retainedEncoded: Int { lock.withLock { encoded } }
  init(loaded: LoadedLocalProject, failure: LocalProjectFailure? = nil) {
    self.loaded = loaded; self.failure = failure
  }
  func release() { gate.signal() }
  func open(_ url: URL, retainedRasterBytes: Int, retainedEncodedBytes: Int,
    cancellation: LocalProjectCancellation) throws -> LoadedLocalProject {
    lock.withLock { raster = retainedRasterBytes; encoded = retainedEncodedBytes }
    calls.increment()
    guard gate.wait(timeout: .now() + 10) == .success else { throw LocalProjectFailure.fileAccess }
    if let failure { throw failure }
    return loaded // Deliberately ignores cancellation to verify publication guards.
  }
  func save(_ snapshot: LocalProjectSnapshot, folder: URL, name: String,
    cancellation: LocalProjectCancellation) throws -> URL {
    throw LocalProjectFailure.fileAccess
  }
}
private final class ProjectBlockingGate: @unchecked Sendable {
  let entered = ProjectCounter()
  private let semaphore = DispatchSemaphore(value: 0)
  func wait() { entered.increment(); _ = semaphore.wait(timeout: .now() + 10) }
  func release() { semaphore.signal() }
}
