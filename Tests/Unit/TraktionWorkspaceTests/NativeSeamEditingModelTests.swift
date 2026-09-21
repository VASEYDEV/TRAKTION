import Foundation
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import XCTest

@MainActor
final class NativeSeamEditingModelTests: XCTestCase, @unchecked Sendable {
  func testDraftCancelApplyMultipleJointsUndoRedoAndCloseReopen() async throws {
    let (captures, base) = try baseResult()
    let editor = NativeSeamEditingModel()
    editor.configure(result: base, captures: captures, preview: base.image)
    let inspection = NativeInspectionModel(editing: editor)
    try inspection.open(result: base, captures: captures, retainedBytes: 0, budget: 268_435_456)
    inspection.resize(width: 4, height: 16)
    inspection.selectJoint(0)
    editor.begin(joint: 0)
    editor.nudge(1)
    try await idle(editor, inspection)
    XCTAssertEqual(editor.draft?.seamRowInOverlap, 3)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertEqual(inspection.frame?.raster.pixels,
      oracle(captures, boundaries: [7, 10], origins: [0, 4, 8], width: 4, height: 16))
    editor.cancelDraft()
    try await idle(editor, inspection)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertEqual(editor.preview, base.image)
    XCTAssertFalse(editor.canUndo)
    editor.begin(joint: 0); editor.nudge(1); editor.apply()
    try await idle(editor, inspection)
    XCTAssertTrue(editor.isModified)
    XCTAssertEqual(editor.preview?.pixels, oracle(captures, boundaries: [7, 10], origins: [0, 4, 8], width: 4, height: 16))
    inspection.close()
    try await idle(editor, inspection)
    XCTAssertTrue(editor.canUndo)
    try inspection.open(result: base, captures: captures, retainedBytes: 0, budget: 268_435_456)
    inspection.resize(width: 4, height: 16)
    inspection.selectJoint(1)
    editor.begin(joint: 1); editor.nudge(2); editor.apply()
    try await idle(editor, inspection)
    let modified = editor.preview
    XCTAssertEqual(modified?.pixels, oracle(captures, boundaries: [7, 12], origins: [0, 4, 8], width: 4, height: 16))
    editor.undo(); try await idle(editor, inspection)
    editor.undo(); try await idle(editor, inspection)
    XCTAssertEqual(editor.preview, base.image)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertFalse(editor.isModified)
    editor.redo(); try await idle(editor, inspection)
    editor.redo(); try await idle(editor, inspection)
    XCTAssertEqual(editor.preview, modified)
    XCTAssertEqual(inspection.result, base, "Base plan and bitmap remain consistent and immutable")
    editor.begin(joint: 1); editor.nudge(-1)
    inspection.close()
    try await idle(editor, inspection)
    XCTAssertNil(editor.draft)
    XCTAssertEqual(editor.preview, modified)
  }

  func testRapidDraftFramesCoalesceAndCancellationRestoresOriginalPixels() async throws {
    let (captures, base) = try baseResult()
    let editor = NativeSeamEditingModel()
    editor.configure(result: base, captures: captures, preview: base.image)
    let renderer = BlockingCompositionRenderer()
    defer { renderer.release() }
    let inspection = NativeInspectionModel(renderer: renderer, editing: editor)
    try inspection.open(result: base, captures: captures, retainedBytes: 0, budget: 268_435_456)
    inspection.resize(width: 4, height: 16)
    inspection.selectJoint(0)
    try await idle(editor, inspection)
    editor.begin(joint: 0)
    try await idle(editor, inspection)
    editor.setSeam(3)
    try await until { renderer.calls == 1 }
    for index in 0..<50 { editor.setSeam(index.isMultiple(of: 2) ? 3 : 4) }
    XCTAssertEqual(renderer.calls, 1)
    XCTAssertNil(inspection.frame)
    XCTAssertFalse(renderer.calledOnMain)
    renderer.release()
    try await idle(editor, inspection)
    XCTAssertEqual(renderer.calls, 2, "Only the newest pending composition is rendered")
    XCTAssertEqual(inspection.frame?.raster.pixels,
      oracle(captures, boundaries: [8, 10], origins: [0, 4, 8], width: 4, height: 16))
    editor.cancelDraft()
    try await idle(editor, inspection)
    XCTAssertEqual(inspection.frame?.raster, base.image)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertFalse(editor.canUndo)
  }

  func testAdmissionIsOverflowSafeAndIncludesPreviewTransition() async throws {
    let (_, base) = try baseResult()
    let editor = NativeSeamEditingModel()
    editor.admit(retainedBytes: 216_269_648, budget: 268_435_456)
    XCTAssertTrue(editor.isAdmitted)
    XCTAssertEqual(216_269_648 + NativeSeamEditingModel.reservedBytes, 249_824_080)
    for retained in [-1, Int.max, 268_435_456 - NativeSeamEditingModel.reservedBytes + 1] {
      editor.admit(retainedBytes: retained, budget: 268_435_456)
      XCTAssertFalse(editor.isAdmitted)
    }
    editor.admit(retainedBytes: 0, budget: NativeSeamEditingModel.reservedBytes - 1)
    XCTAssertFalse(editor.isAdmitted)
    editor.configure(result: base, captures: [], preview: base.image)
    XCTAssertNil(editor.document)
    XCTAssertNotNil(editor.failure)
  }

  func testCancelledApplyAndResetRejectCancellationIgnoringWorker() async throws {
    let (captures, base) = try baseResult()
    let renderer = BlockingSeamRenderer()
    defer { renderer.release() }
    let editor = NativeSeamEditingModel(renderer: renderer)
    editor.configure(result: base, captures: captures, preview: base.image)
    editor.admit(retainedBytes: 0, budget: 268_435_456)
    editor.begin(joint: 0); editor.nudge(1); editor.apply()
    try await until { renderer.calls == 1 }
    XCTAssertTrue(editor.isRendering)
    XCTAssertFalse(renderer.calledOnMain)
    XCTAssertEqual(editor.document?.plan, base.plan, "Commit waits for the bounded preview")
    editor.cancelDraft()
    XCTAssertTrue(editor.isRendering, "The worker slot stays occupied until completion")
    renderer.release()
    try await idle(editor)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertEqual(editor.preview, base.image)
    XCTAssertFalse(editor.canUndo)

    let resetRenderer = BlockingSeamRenderer()
    defer { resetRenderer.release() }
    let resetEditor = NativeSeamEditingModel(renderer: resetRenderer)
    let inspection = NativeInspectionModel(editing: resetEditor)
    let worker = SeamWorkspaceWorker(captures: captures, result: base)
    let workspace = NativeWorkspaceModel(worker: worker, inspection: inspection)
    workspace.importCaptures(from: []); try await until { !workspace.isBusy }
    workspace.confirmOrder(); workspace.reconstruct(); try await until { !workspace.isBusy }
    workspace.inspectResult()
    resetEditor.begin(joint: 0); resetEditor.nudge(1); resetEditor.apply()
    try await until { resetRenderer.calls == 1 }
    workspace.reset(); workspace.importCaptures(from: [])
    XCTAssertTrue(workspace.isBusy)
    XCTAssertNil(workspace.result)
    XCTAssertNil(resetEditor.document)
    XCTAssertTrue(workspace.captures.isEmpty)
    resetRenderer.release(); try await until { !workspace.isBusy }
    XCTAssertNil(workspace.resultPreview)
    XCTAssertNil(resetEditor.document)
    workspace.importCaptures(from: []); try await until { !workspace.isBusy }
    workspace.confirmOrder(); workspace.reconstruct(); try await until { !workspace.isBusy }
    workspace.inspectResult()
    XCTAssertFalse(resetEditor.isModified)
    XCTAssertFalse(resetEditor.canUndo)
    workspace.importCaptures(from: []); try await until { !workspace.isBusy }
    XCTAssertNil(resetEditor.document)
  }

  func testPreviewFailureCannotCommitAndCancelledNoOpDoesNotCreateHistory() async throws {
    let (captures, base) = try baseResult()
    let editor = NativeSeamEditingModel(renderer: FailingSeamRenderer())
    editor.configure(result: base, captures: captures, preview: base.image)
    editor.admit(retainedBytes: 0, budget: 268_435_456)
    editor.begin(joint: 0); editor.apply()
    XCTAssertNil(editor.draft)
    XCTAssertFalse(editor.canUndo)
    editor.begin(joint: 0); editor.nudge(1); editor.apply()
    try await idle(editor)
    XCTAssertEqual(editor.document?.plan, base.plan)
    XCTAssertEqual(editor.preview, base.image)
    XCTAssertFalse(editor.canUndo)
    XCTAssertNotNil(editor.failure)
    XCTAssertNotNil(editor.draft)
    editor.setSeam(Int.max)
    XCTAssertEqual(editor.draft?.seamRowInOverlap, 3)

    let undoEditor = NativeSeamEditingModel(renderer: FailSecondSeamRenderer())
    undoEditor.configure(result: base, captures: captures, preview: base.image)
    let inspection = NativeInspectionModel(editing: undoEditor)
    try inspection.open(result: base, captures: captures, retainedBytes: 0, budget: 268_435_456)
    undoEditor.begin(joint: 0); undoEditor.nudge(1); undoEditor.apply()
    try await idle(undoEditor, inspection)
    let committed = undoEditor.document?.plan
    let committedPreview = undoEditor.preview
    inspection.close()
    try inspection.open(result: base, captures: captures, retainedBytes: 0, budget: 268_435_456)
    XCTAssertNil(inspection.jointIndex)
    undoEditor.undo()
    try await idle(undoEditor, inspection)
    XCTAssertEqual(undoEditor.document?.plan, committed)
    XCTAssertEqual(undoEditor.preview, committedPreview)
    XCTAssertTrue(undoEditor.canUndo)
    XCTAssertFalse(undoEditor.canRedo)
    XCTAssertNotNil(undoEditor.failure, "Failures remain available in Entire result after reopening")
  }

  func testPreviewResamplingMatchesOriginalPreviewAtNonDivisibleDimensions() async throws {
    let source = try RasterImage(width: 5, height: 5001, pixels: (0..<5 * 5001 * 4).map { UInt8($0 % 251) })
    let first = CaptureAsset(id: "a", sourceName: "a", image: try RasterImage(width: 5, height: 3001, pixels: Array(source.pixels.prefix(5 * 3001 * 4))))
    let second = CaptureAsset(id: "b", sourceName: "b", image: try RasterImage(width: 5, height: 3001, pixels: Array(source.pixels.suffix(5 * 3001 * 4))))
    let plan = ReconstructionPlan(axis: .vertical, outputWidth: 5, outputHeight: 5001,
      placements: [CapturePlacement(captureID: "a", originY: 0, width: 5, height: 3001), CapturePlacement(captureID: "b", originY: 2000, width: 5, height: 3001)],
      joints: [JointDiagnosis(precedingCaptureID: "a", followingCaptureID: "b", overlapRows: 1001, seamRowInOverlap: 500,
        outputSeamRow: 2500, normalizedMeanAbsoluteError: 0, changedPixelFraction: 0, confidence: .exact)])
    let actual = try SeamPreviewRenderer().render(plan: plan, captures: [second, first], isCancelled: { false })
    let expected = try NativeRasterPreview.make(source, maximumDimension: NativeRasterPreview.maximumResultDimension,
      maximumPixels: NativeRasterPreview.maximumResultPixels, isCancelled: { false })
    XCTAssertEqual(actual, expected)
  }

  private func baseResult() throws -> ([CaptureAsset], ReconstructionResult) {
    let (captures, plan) = try markedFixture()
    let image = try RasterImage(width: 4, height: 16,
      pixels: oracle(captures, boundaries: [6, 10], origins: [0, 4, 8], width: 4, height: 16))
    return (captures, ReconstructionResult(plan: plan, image: image))
  }

  private func idle(_ editor: NativeSeamEditingModel, _ inspection: NativeInspectionModel? = nil) async throws {
    try await until { !editor.isRendering && inspection?.isRendering != true }
  }

  private func until(_ predicate: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
    while !predicate() {
      if ContinuousClock.now > deadline { throw SeamTestTimeout.timeout }
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}

private enum SeamTestTimeout: Error { case timeout }
private struct FailingSeamRenderer: SeamPreviewRendering {
  func render(plan: ReconstructionPlan, captures: [CaptureAsset], isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    throw SeamEditingFailure.resourceLimit
  }
}
private struct SeamWorkspaceWorker: NativeWorkspaceWorking {
  let captures: [CaptureAsset]
  let result: ReconstructionResult
  func importCaptures(from urls: [URL], retainedRasterBytes: Int, isCancelled: @Sendable () -> Bool) throws -> [CaptureAsset] { captures }
  func reconstruct(_ captures: [CaptureAsset]) throws -> ReconstructionResult { result }
}
private final class BlockingSeamRenderer: SeamPreviewRendering, @unchecked Sendable {
  private let condition = NSCondition()
  private var blocked = true
  private var count = 0
  private var main = false
  var calls: Int { condition.withLock { count } }
  var calledOnMain: Bool { condition.withLock { main } }
  func release() { condition.withLock { blocked = false; condition.broadcast() } }
  func render(plan: ReconstructionPlan, captures: [CaptureAsset], isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    condition.lock()
    count += 1; main = Thread.isMainThread
    while blocked { condition.wait() }
    condition.unlock()
    return try SeamPreviewRenderer().render(plan: plan, captures: captures, isCancelled: { false })
  }
}

private final class BlockingCompositionRenderer: InspectionRendering, @unchecked Sendable {
  private let condition = NSCondition()
  private var blocked = true
  private var count = 0
  private var main = false
  var calls: Int { condition.withLock { count } }
  var calledOnMain: Bool { condition.withLock { main } }
  func release() { condition.withLock { blocked = false; condition.broadcast() } }
  func render(_ source: RasterImage, viewport: InspectionViewport, isCancelled: @Sendable () -> Bool) throws -> InspectionFrame {
    try InspectionRasterRenderer().render(source, viewport: viewport, isCancelled: isCancelled)
  }
  func renderComposition(_ source: PlannedRasterRenderer, viewport: InspectionViewport, isCancelled: @Sendable () -> Bool) throws -> InspectionFrame {
    condition.lock()
    count += 1; main = Thread.isMainThread
    while blocked { condition.wait() }
    condition.unlock()
    return try InspectionRasterRenderer().renderComposition(source, viewport: viewport, isCancelled: { false })
  }
}

private final class FailSecondSeamRenderer: SeamPreviewRendering, @unchecked Sendable {
  private let lock = NSLock()
  private var calls = 0
  func render(plan: ReconstructionPlan, captures: [CaptureAsset], isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    let count = lock.withLock { calls += 1; return calls }
    if count > 1 { throw SeamEditingFailure.resourceLimit }
    return try SeamPreviewRenderer().render(plan: plan, captures: captures, isCancelled: isCancelled)
  }
}
