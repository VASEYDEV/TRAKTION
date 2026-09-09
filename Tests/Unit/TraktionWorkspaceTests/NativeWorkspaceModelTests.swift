import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import TraktionVision
import XCTest

@MainActor
// XCTest discovery crosses isolation; all test state is local or MainActor-bound.
final class NativeWorkspaceModelTests: XCTestCase, @unchecked Sendable {
  func testExplicitOrderAndStableIdentityReachWorkerUnchanged() async throws {
    let worker = try ControlledWorkspaceWorker()
    let model = NativeWorkspaceModel(worker: worker)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    let original = model.captures
    XCTAssertEqual(original, worker.assets)
    XCTAssertFalse(model.canReconstruct)
    model.reconstruct()
    XCTAssertEqual(worker.snapshot.reconstructionCalls, 0)
    model.confirmOrder()
    XCTAssertTrue(model.canReconstruct)
    model.moveCapture(id: original[0].id, offset: 1)
    XCTAssertEqual(model.captures.map(\.id), original.reversed().map(\.id))
    XCTAssertFalse(model.orderConfirmed)
    model.confirmOrder()
    model.reconstruct()
    try await until { !model.isBusy }
    XCTAssertEqual(worker.snapshot.lastOrder, original.reversed().map(\.id))
    XCTAssertFalse(worker.snapshot.calledOnMainThread)
    XCTAssertEqual(model.result, worker.output)
    model.moveCapture(id: original[0].id, offset: -1)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertFalse(model.orderConfirmed)
    model.confirmOrder()
    model.removeCapture(id: original[1].id)
    XCTAssertEqual(model.captures.map(\.id), [original[0].id])
    XCTAssertEqual(Set(model.thumbnails.keys), [original[0].id])
    XCTAssertFalse(model.canReconstruct)
    XCTAssertFalse(model.orderConfirmed)
  }

  func testCancelAndResetKeepWorkerOccupiedUntilImportDrains() async throws {
    let worker = try ControlledWorkspaceWorker(blockImport: true)
    defer { worker.releaseImport() }
    let model = NativeWorkspaceModel(worker: worker)
    model.importCaptures(from: [])
    try await until { worker.snapshot.importCalls == 1 }
    // The main actor remains responsive while a synchronous worker is blocked.
    XCTAssertEqual(model.operation, .importing)
    XCTAssertFalse(worker.snapshot.calledOnMainThread)
    model.cancel()
    model.importCaptures(from: [])
    model.reset()
    model.importCaptures(from: [])
    XCTAssertTrue(model.isBusy)
    XCTAssertTrue(model.isCancelling)
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertEqual(worker.snapshot.importCalls, 1)
    worker.releaseImport()
    try await until { !model.isBusy }
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertNil(model.failure)
    XCTAssertFalse(model.isCancelling)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    XCTAssertEqual(worker.snapshot.importCalls, 2)
    XCTAssertEqual(model.captures, worker.assets)
  }

  func testResetSuppressesCompletedEngineResultAndPreventsReentry() async throws {
    let worker = try ControlledWorkspaceWorker(blockReconstruction: true)
    defer { worker.releaseReconstruction() }
    let model = NativeWorkspaceModel(worker: worker)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    model.confirmOrder()
    model.reconstruct()
    try await until { worker.snapshot.reconstructionCalls == 1 }
    model.reset()
    model.importCaptures(from: [])
    model.reconstruct()
    XCTAssertTrue(model.isBusy)
    XCTAssertTrue(model.isCancelling)
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertEqual(worker.snapshot.importCalls, 1)
    worker.releaseReconstruction()
    try await until { !model.isBusy }
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertNil(model.failure)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    model.confirmOrder()
    model.reconstruct()
    try await until { !model.isBusy }
    XCTAssertEqual(model.result, worker.output)
    XCTAssertEqual(worker.snapshot.reconstructionCalls, 2)
  }

  func testFailedAndCancelledReplacementPreservePriorWorkspace() async throws {
    let worker = try ControlledWorkspaceWorker()
    defer { worker.releaseImport() }
    let model = NativeWorkspaceModel(worker: worker)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    model.confirmOrder()
    model.reconstruct()
    try await until { !model.isBusy }
    let oldCaptures = model.captures
    let oldResult = model.result
    let oldPreview = model.resultPreview
    let oldThumbnails = model.thumbnails
    worker.setImportFailure(.invalidFile("broken.png"))
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    XCTAssertEqual(model.failure, .importFailure(.invalidFile("broken.png")))
    XCTAssertEqual(model.captures, oldCaptures)
    XCTAssertEqual(model.result, oldResult)
    XCTAssertEqual(model.resultPreview, oldPreview)
    XCTAssertEqual(model.thumbnails, oldThumbnails)
    XCTAssertTrue(model.orderConfirmed)
    let oldInputBytes = oldCaptures.reduce(0) { $0 + $1.image.pixels.count }
    let oldThumbnailBytes = oldThumbnails.values.reduce(0) { $0 + $1.pixels.count }
    let retainedBytes = oldInputBytes + oldThumbnailBytes * 2
      + oldResult!.image.pixels.count + oldPreview!.pixels.count * 2
    XCTAssertEqual(worker.snapshot.retainedBytes, retainedBytes)
    worker.setImportFailure(nil)
    worker.blockNextImport()
    model.importCaptures(from: [])
    try await until { worker.snapshot.importCalls == 3 }
    model.cancel()
    worker.releaseImport()
    try await until { !model.isBusy }
    XCTAssertEqual(model.captures, oldCaptures)
    XCTAssertEqual(model.result, oldResult)
    XCTAssertTrue(model.orderConfirmed)
    XCTAssertEqual(model.failure, .importFailure(.invalidFile("broken.png")))
    model.dismissFailure()
    model.reportPickerFailure("The file provider could not open the selection.")
    XCTAssertEqual(model.failure, .selection("The file provider could not open the selection."))
    XCTAssertEqual(model.result, oldResult)
  }

  func testCancellationPreservesConfirmedCapturesAndAllowsRetryAfterDrain() async throws {
    let worker = try ControlledWorkspaceWorker(blockReconstruction: true)
    defer { worker.releaseReconstruction() }
    let model = NativeWorkspaceModel(worker: worker)
    model.importCaptures(from: [])
    try await until { !model.isBusy }
    model.confirmOrder()
    model.reconstruct()
    try await until { worker.snapshot.reconstructionCalls == 1 }
    model.cancel()
    XCTAssertFalse(model.canReconstruct)
    worker.releaseReconstruction()
    try await until { !model.isBusy }
    XCTAssertEqual(model.captures, worker.assets)
    XCTAssertTrue(model.orderConfirmed)
    XCTAssertTrue(model.canReconstruct)
    XCTAssertNil(model.result)
    model.reconstruct()
    try await until { !model.isBusy }
    XCTAssertEqual(model.result, worker.output)
  }

  func testRasterAdmissionRejectsThumbnailsAndOutputBeforeAllocationOrEngine() async throws {
    let worker = try ControlledWorkspaceWorker()
    let inputBytes = worker.assets.reduce(0) { $0 + $1.image.pixels.count }
    let previewRefusal = NativeWorkspaceModel(
      worker: worker, limits: PNGImportLimits(maximumRetainedRasterBytes: inputBytes)
    )
    previewRefusal.importCaptures(from: [])
    try await until { !previewRefusal.isBusy }
    guard case .importFailure(.resourceLimitExceeded) = previewRefusal.failure else {
      return XCTFail("Expected thumbnail admission refusal")
    }
    XCTAssertTrue(previewRefusal.captures.isEmpty)
    XCTAssertTrue(previewRefusal.thumbnails.isEmpty)
    let outputRefusal = NativeWorkspaceModel(
      worker: worker, limits: PNGImportLimits(maximumRetainedRasterBytes: inputBytes * 3)
    )
    outputRefusal.importCaptures(from: [])
    try await until { !outputRefusal.isBusy }
    XCTAssertEqual(outputRefusal.captures, worker.assets)
    outputRefusal.confirmOrder()
    outputRefusal.reconstruct()
    guard case .reconstruction(.resourceLimitExceeded) = outputRefusal.failure else {
      return XCTFail("Expected output reservation refusal")
    }
    XCTAssertEqual(worker.snapshot.reconstructionCalls, 0)
    XCTAssertNil(outputRefusal.result)
  }

  func testCleanupFailureRemainsVisibleAfterCancellationAndReset() async throws {
    for reset in [false, true] {
      let worker = try ControlledWorkspaceWorker(blockImport: true)
      defer { worker.releaseImport() }
      worker.setImportFailure(.cleanupFailed)
      let model = NativeWorkspaceModel(worker: worker)
      model.importCaptures(from: [])
      try await until { worker.snapshot.importCalls == 1 }
      if reset { model.reset() } else { model.cancel() }
      worker.releaseImport()
      try await until { !model.isBusy }
      XCTAssertEqual(model.failure, .importFailure(.cleanupFailed))
      XCTAssertTrue(model.captures.isEmpty)
      XCTAssertNil(model.result)
    }
  }

  func testPreviewIsBoundedSourceSamplingAndCancellationThrows() async throws {
    let source = try SyntheticFixtureFactory.document(width: 400, height: 800, seed: 17)
    let original = source.pixels
    let preview = try NativeRasterPreview.make(
      source, maximumDimension: 224, maximumPixels: 224 * 224, isCancelled: { false }
    )
    XCTAssertLessThanOrEqual(max(preview.width, preview.height), 224)
    XCTAssertLessThanOrEqual(preview.width * preview.height, 224 * 224)
    for y in 0..<preview.height {
      for x in 0..<preview.width {
        let input = source.byteOffset(x: x * source.width / preview.width, y: y * source.height / preview.height)
        let output = preview.byteOffset(x: x, y: y)
        XCTAssertEqual(Array(preview.pixels[output..<output + 4]), Array(original[input..<input + 4]))
      }
    }
    XCTAssertEqual(source.pixels, original)
    XCTAssertThrowsError(try NativeRasterPreview.make(
      source, maximumDimension: 224, maximumPixels: 224 * 224, isCancelled: { true }
    )) { XCTAssertEqual($0 as? PNGImportFailure, .cancelled) }
  }

  private func until(_ condition: @MainActor () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(5)
    while !condition() {
      guard Date() < deadline else { throw WorkspaceTestError.timedOut }
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}

private enum WorkspaceTestError: Error { case timedOut }

/// Gates deliberately ignore cancellation to emulate synchronous codec/engine
/// work that cannot stop immediately. All mutable test state is locked.
private final class ControlledWorkspaceWorker: NativeWorkspaceWorking, @unchecked Sendable {
  struct Snapshot {
    var importCalls = 0
    var reconstructionCalls = 0
    var calledOnMainThread = false
    var lastOrder: [CaptureID] = []
    var retainedBytes = 0
  }
  let assets: [CaptureAsset]
  let output: ReconstructionResult
  private let condition = NSCondition()
  private var state = Snapshot()
  private var importBlocked: Bool
  private var reconstructionBlocked: Bool
  private var importFailure: PNGImportFailure?

  init(blockImport: Bool = false, blockReconstruction: Bool = false) throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    assets = fixture.captures
    output = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    importBlocked = blockImport
    reconstructionBlocked = blockReconstruction
  }

  var snapshot: Snapshot {
    condition.lock()
    defer { condition.unlock() }
    return state
  }

  func importCaptures(
    from urls: [URL], retainedRasterBytes: Int, isCancelled: @Sendable () -> Bool
  ) throws -> [CaptureAsset] {
    condition.lock()
    defer { condition.unlock() }
    state.importCalls += 1
    state.retainedBytes = retainedRasterBytes
    state.calledOnMainThread = state.calledOnMainThread || Thread.isMainThread
    while importBlocked { condition.wait() }
    if let importFailure { throw importFailure }
    return assets
  }

  func reconstruct(_ captures: [CaptureAsset]) throws -> ReconstructionResult {
    condition.lock()
    defer { condition.unlock() }
    state.reconstructionCalls += 1
    state.lastOrder = captures.map(\.id)
    state.calledOnMainThread = state.calledOnMainThread || Thread.isMainThread
    while reconstructionBlocked { condition.wait() }
    return output
  }

  func setImportFailure(_ failure: PNGImportFailure?) {
    condition.lock()
    defer { condition.unlock() }
    importFailure = failure
  }

  func blockNextImport() {
    condition.lock()
    defer { condition.unlock() }
    importBlocked = true
  }

  func releaseImport() {
    condition.lock()
    defer { condition.unlock() }
    importBlocked = false
    condition.broadcast()
  }

  func releaseReconstruction() {
    condition.lock()
    defer { condition.unlock() }
    reconstructionBlocked = false
    condition.broadcast()
  }
}
