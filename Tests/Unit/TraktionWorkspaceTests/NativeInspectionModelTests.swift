import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import TraktionVision
import XCTest

@MainActor
final class NativeInspectionModelTests: XCTestCase, @unchecked Sendable {
  func testPanZoomFitAndEdgesRemainInSourceCoordinates() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let model = NativeInspectionModel()
    try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 32, height: 40)
    try await idle(model)
    XCTAssertEqual(model.viewport?.zoom, 1.0 / 6)
    model.setZoom(1)
    model.edge(bottom: false)
    model.pan(dx: -1_000, dy: 0)
    model.pan(dx: 20, dy: 50)
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.x, 20)
    XCTAssertEqual(model.frame?.viewport.y, 50)
    model.pan(dx: 10_000, dy: 10_000)
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.x, 32)
    XCTAssertEqual(model.frame?.viewport.y, 200)
    model.setZoom(2)
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.zoom, 2)
    model.fit()
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.x, 0)
    XCTAssertEqual(model.frame?.viewport.y, 0)
    XCTAssertEqual(model.frame?.viewport.zoom, 1.0 / 6)
  }

  func testFitHasNoFixedZoomFloorForTallNarrowRasters() async throws {
    // Isolate inspection geometry from registration: a small byte count can
    // still have a large edge. This shape is below the workspace pixel limits.
    let image = try RasterImage(width: 1, height: 262_145,
      pixels: [UInt8](repeating: 255, count: 262_145 * 4))
    let result = ReconstructionResult(plan: ReconstructionPlan(axis: .vertical,
      outputWidth: 1, outputHeight: image.height, placements: [], joints: []), image: image)
    let model = NativeInspectionModel()
    try model.open(result: result, captures: [], retainedBytes: image.pixels.count, budget: 268_435_456)
    model.resize(width: 2, height: 2)
    try await idle(model)
    let fit = 2.0 / Double(image.height)
    XCTAssertEqual(model.frame?.viewport.zoom, fit)
    XCTAssertLessThan(fit, 1.0 / 65_536)
    let formatter = NumberFormatter()
    formatter.locale = .current
    let percentText = try XCTUnwrap(model.frame?.viewport.zoomPercentText)
    let displayedPercentage = try XCTUnwrap(formatter.number(from: String(percentText.dropLast()))).doubleValue
    XCTAssertGreaterThan(displayedPercentage, 0)
    XCTAssertEqual(displayedPercentage, fit * 100, accuracy: 1e-9)
    model.setZoom(1)
    model.fit()
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.zoom, fit)
    model.setZoom(fit / 2)
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport.zoom, fit, "Zoom out stops at the actual fit scale")
    XCTAssertEqual(model.frame?.viewport.y, 0)
  }

  func testFractionalZoomCanReachTheLastSourceRowAndColumn() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let model = NativeInspectionModel()
    try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 10, height: 10)
    model.setZoom(1.1)
    model.pan(dx: 10_000, dy: 10_000)
    try await idle(model)
    let frame = try XCTUnwrap(model.frame)
    XCTAssertEqual(Array(frame.raster.pixels.suffix(4)), Array(result.image.pixels.suffix(4)))
    model.edge(bottom: true)
    try await idle(model)
    XCTAssertEqual(model.frame?.viewport, frame.viewport)
  }

  func testJointAndSourceSelectionPreserveIdentityConfidenceAndResetCamera() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let model = NativeInspectionModel()
    try model.open(result: result, captures: fixture.captures.reversed(), retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 32, height: 10)
    model.selectJoint(1)
    try await idle(model)
    XCTAssertEqual(model.joint?.diagnosis, result.plan.joints[1])
    XCTAssertEqual(model.viewport?.zoom, 1)
    XCTAssertEqual(model.viewport?.y, Double(result.plan.joints[1].outputSeamRow - 5))
    model.selectSource(.preceding)
    try await idle(model)
    XCTAssertEqual(model.sourceName, fixture.captures[1].sourceName)
    XCTAssertEqual(model.sourceWidth, fixture.captures[1].image.width)
    XCTAssertEqual(model.viewport?.y, Double(try XCTUnwrap(model.joint).precedingSeamRow - 5))
    model.selectSource(.following)
    try await idle(model)
    XCTAssertEqual(model.sourceName, fixture.captures[2].sourceName)
    model.selectJoint(nil)
    try await idle(model)
    XCTAssertNil(model.joint)
    XCTAssertEqual(model.source, .result)
    XCTAssertEqual(model.sourceName, "Result")
    XCTAssertEqual(model.result, result)
    XCTAssertNil(model.failure)
  }

  func testRapidRequestsCoalesceAndRejectAnObsoleteWorkerFrame() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let renderer = BlockingInspectionRenderer()
    defer { renderer.release() }
    let model = NativeInspectionModel(renderer: renderer)
    try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 32, height: 20)
    try await until { renderer.calls == 1 }
    model.setZoom(1)
    model.edge(bottom: false)
    for _ in 0..<50 { model.pan(dx: 0, dy: 2) }
    XCTAssertTrue(model.isRendering)
    XCTAssertNil(model.frame)
    XCTAssertEqual(renderer.calls, 1)
    XCTAssertFalse(renderer.calledOnMainThread)
    renderer.release()
    try await idle(model)
    XCTAssertEqual(renderer.calls, 2, "Only one pending viewport may be retained")
    XCTAssertEqual(model.frame?.viewport.y, 100)
    XCTAssertEqual(model.frame?.viewport.zoom, 1)
  }

  func testDismissClearsEverythingAndWaitsForCancelledWorkerBeforeReopen() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let renderer = BlockingInspectionRenderer()
    defer { renderer.release() }
    let model = NativeInspectionModel(renderer: renderer)
    try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 32, height: 20)
    try await until { renderer.calls == 1 }
    model.selectJoint(1)
    model.close()
    XCTAssertFalse(model.isOpen)
    XCTAssertNil(model.result)
    XCTAssertNil(model.joint)
    XCTAssertNil(model.frame)
    XCTAssertNil(model.viewport)
    XCTAssertTrue(model.isRendering)
    XCTAssertThrowsError(try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456))
    renderer.release()
    try await idle(model)
    XCTAssertEqual(renderer.calls, 1)
    XCTAssertNil(model.frame, "A deliberately cancellation-ignoring worker must not publish")
    try model.open(result: result, captures: fixture.captures, retainedBytes: 0, budget: 268_435_456)
    model.resize(width: 16, height: 20)
    try await idle(model)
    XCTAssertNil(model.joint)
    XCTAssertEqual(model.source, .result)
    XCTAssertEqual(model.viewport?.y, 0)
  }

  func testInspectionAdmissionIncludesRetainedWorkspaceAndOverflowSafeReserve() async throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    let model = NativeInspectionModel()
    let retained = fixture.captures.reduce(result.image.pixels.count) { $0 + $1.image.pixels.count }
    let total = retained + InspectionViewport.reservedBytes
    XCTAssertThrowsError(try model.open(result: result, captures: fixture.captures, retainedBytes: retained, budget: total - 1))
    XCTAssertFalse(model.isOpen)
    XCTAssertNil(model.result)
    XCTAssertThrowsError(try model.open(result: result, captures: fixture.captures, retainedBytes: Int.max, budget: Int.max))
    try model.open(result: result, captures: fixture.captures, retainedBytes: retained, budget: total)
    XCTAssertTrue(model.isOpen)
  }

  func testWorkspaceResetAndReplacementCannotOverlapDrainingInspection() async throws {
    let worker = try InspectionWorkspaceWorker()
    let renderer = BlockingInspectionRenderer()
    defer { renderer.release() }
    let inspection = NativeInspectionModel(renderer: renderer)
    let workspace = NativeWorkspaceModel(worker: worker, inspection: inspection)
    workspace.importCaptures(from: [])
    try await until { !workspace.isBusy }
    workspace.confirmOrder()
    workspace.reconstruct()
    try await until { !workspace.isBusy }
    workspace.inspectResult()
    inspection.resize(width: 32, height: 20)
    try await until { renderer.calls == 1 }
    workspace.reset()
    workspace.importCaptures(from: [])
    XCTAssertTrue(workspace.isBusy)
    XCTAssertTrue(workspace.captures.isEmpty)
    XCTAssertNil(workspace.result)
    XCTAssertFalse(inspection.isOpen)
    renderer.release()
    try await until { !workspace.isBusy }
    XCTAssertNil(inspection.frame)
    workspace.importCaptures(from: [])
    try await until { !workspace.isBusy }
    workspace.confirmOrder()
    workspace.reconstruct()
    try await until { !workspace.isBusy }
    workspace.inspectResult()
    inspection.resize(width: 32, height: 20)
    try await idle(inspection)
    workspace.importCaptures(from: [])
    try await until { !workspace.isBusy }
    XCTAssertNil(inspection.frame)
    XCTAssertFalse(inspection.isOpen)
    XCTAssertNil(workspace.result)
    XCTAssertFalse(workspace.orderConfirmed)
  }

  private func idle(_ model: NativeInspectionModel) async throws {
    try await until { !model.isRendering }
  }

  private func until(_ predicate: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !predicate() {
      guard ContinuousClock.now < deadline else { throw InspectionTestFailure.timeout }
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}

private enum InspectionTestFailure: Error { case timeout }

private final class BlockingInspectionRenderer: InspectionRendering, @unchecked Sendable {
  private let condition = NSCondition()
  private var blocked = true
  private var count = 0
  private var mainThread = false
  var calls: Int { condition.withLock { count } }
  var calledOnMainThread: Bool { condition.withLock { mainThread } }

  func release() { condition.withLock { blocked = false; condition.broadcast() } }

  func render(_ source: RasterImage, viewport: InspectionViewport, isCancelled: @Sendable () -> Bool) throws -> InspectionFrame {
    condition.lock()
    count += 1
    mainThread = mainThread || Thread.isMainThread
    while blocked { condition.wait() }
    condition.unlock()
    // Deliberately ignores cancellation to verify generation checks independently.
    return try InspectionRasterRenderer().render(source, viewport: viewport, isCancelled: { false })
  }
}

private struct InspectionWorkspaceWorker: NativeWorkspaceWorking {
  let fixture: SyntheticFixture
  init() throws { fixture = try SyntheticFixtureFactory.baseline() }
  func importCaptures(from urls: [URL], retainedRasterBytes: Int, isCancelled: @Sendable () -> Bool) throws -> [CaptureAsset] { fixture.captures }
  func reconstruct(_ captures: [CaptureAsset]) throws -> ReconstructionResult {
    try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures), axis: .vertical)
  }
}
