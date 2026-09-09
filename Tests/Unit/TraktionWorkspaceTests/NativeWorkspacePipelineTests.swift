import FixtureForgeKit
import Foundation
import TraktionDomain
import TraktionUI
import TraktionVision
import XCTest

// XCTest discovery crosses isolation; all test state is local or MainActor-bound.
final class NativeWorkspacePipelineTests: XCTestCase, @unchecked Sendable {
  @MainActor
  func testRealImportRequiresConfirmedOrderAndReconstructsExactSource() async throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let files = try PipelineFiles(images: fixture.captures.map(\.image))
    defer { files.remove() }
    let model = NativeWorkspaceModel()

    model.importCaptures(from: files.urls.reversed())
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    XCTAssertEqual(model.captures.map(\.image), fixture.captures.reversed().map(\.image))
    XCTAssertEqual(model.captures.map(\.sourceName), files.urls.reversed().map(\.lastPathComponent))
    let importedIDs = model.captures.map(\.id)
    let firstImportedID = try XCTUnwrap(importedIDs.first)
    XCTAssertEqual(Set(model.thumbnails.keys), Set(importedIDs))
    XCTAssertFalse(model.orderConfirmed)
    XCTAssertFalse(model.canReconstruct)

    model.reconstruct()
    XCTAssertFalse(model.isBusy)
    XCTAssertNil(model.result)
    model.confirmOrder()
    model.moveCapture(id: firstImportedID, offset: 1)
    XCTAssertEqual(model.captures.map(\.id), Array(importedIDs.reversed()))
    XCTAssertEqual(model.captures.map(\.image), fixture.captures.map(\.image))
    XCTAssertFalse(model.orderConfirmed, "Moving a capture must invalidate the prior confirmation.")
    model.reconstruct()
    XCTAssertFalse(model.isBusy)
    XCTAssertNil(model.result)

    model.confirmOrder()
    XCTAssertTrue(model.canReconstruct)
    model.reconstruct()
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    let result = try XCTUnwrap(model.result)
    XCTAssertEqual(result.image, fixture.source)
    XCTAssertEqual(result.plan.axis, .vertical)
    XCTAssertEqual(result.plan.placements.map(\.captureID), model.captures.map(\.id))
    XCTAssertEqual(result.plan.placements.map(\.originY), fixture.sourceOrigins)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), fixture.expectedOverlaps)
    XCTAssertTrue(result.plan.joints.allSatisfy { $0.confidence == .exact })
    XCTAssertEqual(model.resultPreview, fixture.source)
    try files.assertOriginalsUnchanged()
    model.reset()
    XCTAssertTrue(model.captures.isEmpty)
    XCTAssertTrue(model.thumbnails.isEmpty)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    try files.assertOriginalsUnchanged()
  }

  @MainActor
  func testRealDuplicateImportPreservesTypedRefusalAndCaptureNames() async throws {
    let fixture = try SyntheticFixtureFactory.duplicatePair()
    let files = try PipelineFiles(images: fixture.captures.map(\.image))
    defer { files.remove() }
    let model = NativeWorkspaceModel()
    model.importCaptures(from: files.urls)
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    XCTAssertEqual(model.captures.count, 2)
    let captures = model.captures
    let preceding = try XCTUnwrap(captures.first)
    let following = try XCTUnwrap(captures.last)
    model.confirmOrder()
    model.reconstruct()
    try await waitUntilIdle(model)

    XCTAssertEqual(model.failure, .reconstruction(.duplicateCapture(
      preceding: preceding.id, following: following.id
    )))
    XCTAssertEqual(model.captures, captures)
    XCTAssertEqual(model.thumbnails.count, 2)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertTrue(try XCTUnwrap(model.failureMessage).contains("1. capture-0.png"))
    XCTAssertTrue(try XCTUnwrap(model.failureMessage).contains("2. capture-1.png"))
    try files.assertOriginalsUnchanged()
  }

  @MainActor
  func testRealMissingMiddleImportRefusesToInventCoverage() async throws {
    let fixture = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "native-missing", seed: 7003, variant: .missingMiddle)
    )
    let files = try PipelineFiles(images: fixture.captures.map(\.image))
    defer { files.remove() }
    let model = NativeWorkspaceModel()
    model.importCaptures(from: files.urls)
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    let captures = model.captures
    let first = try XCTUnwrap(captures.first)
    let last = try XCTUnwrap(captures.last)
    model.confirmOrder()
    model.reconstruct()
    try await waitUntilIdle(model)

    guard case .reconstruction(.insufficientOverlap(let preceding, let following, _)) = model.failure else {
      return XCTFail("Expected missing-coverage refusal, got \(String(describing: model.failure)).")
    }
    XCTAssertEqual(preceding, first.id)
    XCTAssertEqual(following, last.id)
    XCTAssertEqual(model.captures, captures)
    XCTAssertEqual(model.thumbnails.count, captures.count)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertTrue(try XCTUnwrap(model.failureMessage).contains("capture-0.png"))
    XCTAssertTrue(try XCTUnwrap(model.failureMessage).contains("capture-1.png"))
    try files.assertOriginalsUnchanged()
  }

  @MainActor
  func testRealDirectionalAmbiguityRemainsARefusalThroughNativePipeline() async throws {
    // The same genuine repeated-band ambiguity exercised by the core golden suite.
    let repeated = try SyntheticFixtureFactory.document(width: 64, height: 16, seed: 8100)
    let forward = try SyntheticFixtureFactory.document(width: 64, height: 32, seed: 8200)
    var noisyForward = forward.pixels
    noisyForward[0] ^= 1
    let images = try [
      RasterImage(width: 64, height: 64, pixels: repeated.pixels + repeated.pixels + forward.pixels),
      RasterImage(width: 64, height: 64, pixels: noisyForward + repeated.pixels + repeated.pixels),
    ]
    let files = try PipelineFiles(images: images)
    defer { files.remove() }
    let model = NativeWorkspaceModel()
    model.importCaptures(from: files.urls)
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    let captures = model.captures
    let preceding = try XCTUnwrap(captures.first)
    let following = try XCTUnwrap(captures.last)
    model.confirmOrder()
    model.reconstruct()
    try await waitUntilIdle(model)

    XCTAssertEqual(model.failure, .reconstruction(.ambiguousOverlapDirection(
      preceding: preceding.id, following: following.id,
      forwardRows: 32, reverseRows: [16, 32]
    )))
    XCTAssertEqual(model.captures, captures)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertTrue(try XCTUnwrap(model.failureMessage).contains("uncertain"))
    try files.assertOriginalsUnchanged()
  }

  @MainActor
  func testInvalidReplacementPreservesSuccessfulWorkspaceAndAllOriginalFiles() async throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let files = try PipelineFiles(images: fixture.captures.map(\.image))
    defer { files.remove() }
    let invalid = files.directory.appendingPathComponent("invalid.png")
    let invalidBytes = Data("This is not a PNG.".utf8)
    try invalidBytes.write(to: invalid, options: .withoutOverwriting)
    let model = NativeWorkspaceModel()
    model.importCaptures(from: files.urls)
    try await waitUntilIdle(model)
    model.confirmOrder()
    model.reconstruct()
    try await waitUntilIdle(model)
    XCTAssertEqual(model.result?.image, fixture.source)
    let previousCaptures = model.captures
    let previousResult = model.result
    let previousThumbnails = model.thumbnails
    let previousPreview = model.resultPreview

    model.importCaptures(from: [files.urls[0], invalid])
    try await waitUntilIdle(model)
    guard case .importFailure(.codec) = model.failure else {
      return XCTFail("Expected a typed import failure, got \(String(describing: model.failure)).")
    }
    XCTAssertEqual(model.captures, previousCaptures)
    XCTAssertEqual(model.result, previousResult)
    XCTAssertEqual(model.thumbnails, previousThumbnails)
    XCTAssertEqual(model.resultPreview, previousPreview)
    XCTAssertTrue(model.orderConfirmed)
    try files.assertOriginalsUnchanged()
    XCTAssertEqual(try Data(contentsOf: invalid), invalidBytes)

    model.importCaptures(from: files.urls)
    try await waitUntilIdle(model)
    XCTAssertNil(model.failure)
    XCTAssertNil(model.result)
    XCTAssertNil(model.resultPreview)
    XCTAssertFalse(model.orderConfirmed)
    XCTAssertEqual(model.captures.map(\.image), fixture.captures.map(\.image))
    XCTAssertTrue(Set(model.captures.map(\.id)).isDisjoint(with: previousCaptures.map(\.id)))
    model.reset()
    XCTAssertTrue(model.captures.isEmpty)
    try files.assertOriginalsUnchanged()
    XCTAssertEqual(try Data(contentsOf: invalid), invalidBytes)
  }

  @MainActor
  private func waitUntilIdle(_ model: NativeWorkspaceModel) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
    while model.isBusy {
      guard ContinuousClock.now < deadline else { throw PipelineTestFailure.timeout }
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}

private enum PipelineTestFailure: Error {
  case timeout
}

private struct PipelineFiles {
  let directory: URL
  let urls: [URL]
  let originalBytes: [Data]

  init(images: [RasterImage]) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-pipeline-\(UUID().uuidString)", isDirectory: true
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    do {
      let urls = try images.enumerated().map { index, image in
        let url = directory.appendingPathComponent("capture-\(index).png")
        try PNGCodec.encodeOpaqueRGBA8(image, to: url)
        return url
      }
      self.directory = directory
      self.urls = urls
      originalBytes = try urls.map { try Data(contentsOf: $0) }
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  func assertOriginalsUnchanged(file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalBytes, file: file, line: line)
  }

  func remove() { try? FileManager.default.removeItem(at: directory) }
}
