import FixtureForgeKit
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import XCTest

final class SeamEditingTests: XCTestCase {
  func testEveryAcceptedBoundarySelectsIndependentOriginalPixels() throws {
    let (captures, plan) = try markedFixture()
    let originals = captures.map(\.image)
    for first in 0...4 {
      for second in 0...4 where 4 + first < 8 + second {
        var document = try SeamEditingDocument(plan: plan, captures: captures.reversed())
        try document.apply(adjustment(plan, joint: 0, row: first))
        try document.apply(adjustment(plan, joint: 1, row: second))
        let raster = try PlannedRasterRenderer(plan: document.plan, captures: captures.reversed())
          .render(RasterSamplingRegion(width: 4, height: 16, x: 0, y: 0, scale: 1), isCancelled: { false })
        XCTAssertEqual(raster.pixels, oracle(captures, boundaries: [4 + first, 8 + second], origins: [0, 4, 8], width: 4, height: 16))
        XCTAssertEqual(document.originalPlan, plan)
        for index in plan.joints.indices {
          XCTAssertEqual(document.plan.joints[index].confidence, plan.joints[index].confidence)
          XCTAssertEqual(document.plan.joints[index].changedPixelFraction, plan.joints[index].changedPixelFraction)
          XCTAssertEqual(document.plan.joints[index].normalizedMeanAbsoluteError, plan.joints[index].normalizedMeanAbsoluteError)
        }
        XCTAssertEqual(document.plan.placements, plan.placements)
      }
    }
    XCTAssertEqual(captures.map(\.image), originals)
  }

  func testDraftNoOpHistoryUndoRedoAndNewBranchAreMetadataOnly() throws {
    let (captures, plan) = try markedFixture()
    var document = try SeamEditingDocument(plan: plan, captures: captures)
    _ = try document.preview(adjustment(plan, joint: 0, row: 3))
    XCTAssertEqual(document.plan, plan)
    XCTAssertFalse(document.canUndo)
    try document.apply(adjustment(plan, joint: 0, row: 2))
    XCTAssertFalse(document.canUndo)
    try document.apply(adjustment(plan, joint: 0, row: 3))
    let first = document.plan
    try document.apply(adjustment(plan, joint: 1, row: 4))
    let second = document.plan
    for expected in [first, plan] { document.undo(); XCTAssertEqual(document.plan, expected) }
    XCTAssertFalse(document.isModified)
    for expected in [first, second] { document.redo(); XCTAssertEqual(document.plan, expected) }
    document.undo()
    try document.apply(adjustment(plan, joint: 1, row: 1))
    XCTAssertFalse(document.canRedo)
    let raster = try PlannedRasterRenderer(plan: document.plan, captures: captures)
      .render(RasterSamplingRegion(width: 4, height: 16, x: 0, y: 0, scale: 1), isCancelled: { false })
    XCTAssertEqual(raster.pixels, oracle(captures, boundaries: [7, 9], origins: [0, 4, 8], width: 4, height: 16))
  }

  func testInvalidOutOfOverlapCrossingAndUnsupportedPlansAreRefused() throws {
    let (captures, plan) = try markedFixture(step: 2)
    let document = try SeamEditingDocument(plan: plan, captures: captures)
    for row in [-1, 7, Int.max] {
      XCTAssertThrowsError(try document.preview(adjustment(plan, joint: 0, row: row))) {
        XCTAssertEqual($0 as? SeamEditingFailure, .outsideProvenOverlap)
      }
    }
    for row in [5, 6] {
      XCTAssertThrowsError(try document.preview(adjustment(plan, joint: 0, row: row))) {
        XCTAssertEqual($0 as? SeamEditingFailure, .crossingSeams)
      }
    }
    XCTAssertThrowsError(try document.preview(SeamAdjustment(precedingCaptureID: "absent", followingCaptureID: "c1", seamRowInOverlap: 2)))
    for invalid in [
      ReconstructionPlan(axis: .horizontal, outputWidth: 4, outputHeight: 12, placements: plan.placements, joints: plan.joints),
      ReconstructionPlan(axis: .vertical, outputWidth: 5, outputHeight: 12, placements: plan.placements, joints: plan.joints),
      ReconstructionPlan(axis: .vertical, outputWidth: 4, outputHeight: 12, placements: Array(plan.placements.dropFirst()), joints: plan.joints)
    ] { XCTAssertThrowsError(try PlannedRasterRenderer(plan: invalid, captures: captures)) }
    var placements = plan.placements
    placements[1] = CapturePlacement(captureID: "c1", originY: Int.max, width: 4, height: 8)
    XCTAssertThrowsError(try PlannedRasterRenderer(plan: ReconstructionPlan(axis: .vertical, outputWidth: 4,
      outputHeight: Int.max, placements: placements, joints: plan.joints), captures: captures))
    var joints = plan.joints
    let old = joints[0]
    joints[0] = JointDiagnosis(precedingCaptureID: old.precedingCaptureID, followingCaptureID: old.followingCaptureID,
      overlapRows: old.overlapRows, seamRowInOverlap: old.seamRowInOverlap, outputSeamRow: old.outputSeamRow,
      normalizedMeanAbsoluteError: 0, changedPixelFraction: 0, confidence: .gap)
    XCTAssertThrowsError(try PlannedRasterRenderer(plan: ReconstructionPlan(axis: .vertical, outputWidth: 4,
      outputHeight: 12, placements: plan.placements, joints: joints), captures: captures)) {
        XCTAssertEqual($0 as? SeamEditingFailure, .unsupportedEvidence)
    }
    XCTAssertThrowsError(try PlannedRasterRenderer(plan: plan, captures: [captures[0], captures[0], captures[2]]))
  }

  func testBoundedSamplingCancellationTransparencyAndLongInput() throws {
    let (captures, plan) = try markedFixture()
    let renderer = try PlannedRasterRenderer(plan: plan, captures: captures)
    for scale in [0.5, 1, 2, 4] {
      let actual = try renderer.render(RasterSamplingRegion(width: 7, height: 11, x: 1, y: 5, scale: scale), isCancelled: { false })
      let full = oracle(captures, boundaries: [6, 10], origins: [0, 4, 8], width: 4, height: 16)
      var expected = [UInt8](repeating: 0, count: 7 * 11 * 4)
      for y in 0..<11 {
        for x in 0..<7 {
          let sx = 1 + Int(Double(x) / scale), sy = 5 + Int(Double(y) / scale)
          if sx < 4 && sy < 16 {
            for channel in 0..<4 { expected[(y * 7 + x) * 4 + channel] = full[(sy * 4 + sx) * 4 + channel] }
          }
        }
      }
      XCTAssertEqual(actual.pixels, expected)
    }
    XCTAssertThrowsError(try renderer.render(RasterSamplingRegion(width: Int.max, height: 2, x: 0, y: 0, scale: 1), isCancelled: { false }))
    XCTAssertThrowsError(try renderer.render(RasterSamplingRegion(width: 2, height: 2, x: 0, y: 0, scale: 1), isCancelled: { true })) {
      XCTAssertEqual($0 as? SeamEditingFailure, .cancelled)
    }
    let width = 1170, height = 2532, step = 1832
    let longCaptures = try (0..<10).map { index in
      CaptureAsset(id: CaptureID("long-\(index)"), sourceName: "duplicate.png",
        image: try RasterImage(width: width, height: height,
          pixels: [UInt8](repeating: UInt8(index + 1), count: width * height * 4)))
    }
    let longPlan = ReconstructionPlan(axis: .vertical, outputWidth: width, outputHeight: 19020,
      placements: longCaptures.enumerated().map { CapturePlacement(captureID: $0.element.id, originY: $0.offset * step, width: width, height: height) },
      joints: (0..<9).map { JointDiagnosis(precedingCaptureID: longCaptures[$0].id, followingCaptureID: longCaptures[$0 + 1].id,
        overlapRows: 700, seamRowInOverlap: 350, outputSeamRow: ($0 + 1) * step + 350,
        normalizedMeanAbsoluteError: 0.001, changedPixelFraction: 0.001, confidence: .strong) })
    var document = try SeamEditingDocument(plan: longPlan, captures: longCaptures)
    try document.apply(adjustment(longPlan, joint: 4, row: 349))
    let source = try PlannedRasterRenderer(plan: document.plan, captures: longCaptures)
    for y in [0, 9510, 18300] {
      let raster = try source.render(RasterSamplingRegion(width: 960, height: 720, x: 0, y: Double(y), scale: 1), isCancelled: { false })
      XCTAssertEqual(raster.pixels.count, 2_764_800)
      for row in 0..<720 {
        let outputRow = y + row
        let boundaries = (1...9).map { $0 * step + ($0 == 5 ? 349 : 350) }
        let expected = UInt8(boundaries.filter { outputRow >= $0 }.count + 1)
        XCTAssertEqual(raster.pixels[row * 960 * 4], expected)
      }
    }
    let preview = try SeamPreviewRenderer().render(plan: document.plan, captures: longCaptures, isCancelled: { false })
    XCTAssertLessThanOrEqual(preview.pixels.count, 4_194_304)
    XCTAssertEqual(document.originalPlan, longPlan)
  }

  func testRealNearExactEvidenceRetainedWhenOriginalPixelSelectionChanges() throws {
    let source = try SyntheticFixtureFactory.document(width: 40, height: 40, seed: 0x53414D50)
    let rowBytes = 40 * 4
    let first = try RasterImage(width: 40, height: 30, pixels: Array(source.pixels[0..<30 * rowBytes]))
    var secondPixels = Array(source.pixels[10 * rowBytes..<40 * rowBytes])
    secondPixels[0] ^= 1
    let captures = [CaptureAsset(id: "a", sourceName: "same.png", image: first),
      CaptureAsset(id: "b", sourceName: "same.png", image: try RasterImage(width: 40, height: 30, pixels: secondPixels))]
    let base = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    XCTAssertEqual(base.plan.joints[0].confidence, .strong)
    var document = try SeamEditingDocument(plan: base.plan, captures: captures)
    try document.apply(adjustment(base.plan, joint: 0, row: 0))
    let edited = try PlannedRasterRenderer(plan: document.plan, captures: captures)
      .render(RasterSamplingRegion(width: 40, height: 40, x: 0, y: 0, scale: 1), isCancelled: { false })
    XCTAssertEqual(edited.pixels, Array(first.pixels[0..<10 * rowBytes]) + secondPixels)
    XCTAssertNotEqual(edited.pixels, base.image.pixels)
    XCTAssertEqual(document.plan.joints[0].normalizedMeanAbsoluteError, base.plan.joints[0].normalizedMeanAbsoluteError)
    document.undo()
    let restored = try PlannedRasterRenderer(plan: document.plan, captures: captures)
      .render(RasterSamplingRegion(width: 40, height: 40, x: 0, y: 0, scale: 1), isCancelled: { false })
    XCTAssertEqual(restored, base.image)
  }
}

func markedFixture(step: Int = 4) throws -> ([CaptureAsset], ReconstructionPlan) {
  let width = 4, height = 8
  let captures = try (0..<3).map { index in
    var pixels: [UInt8] = []
    for row in 0..<height { for column in 0..<width { pixels += [UInt8(50 * index + row), UInt8(column), UInt8(index + 1), 255] } }
    return CaptureAsset(id: CaptureID("c\(index)"), sourceName: "same.png", image: try RasterImage(width: width, height: height, pixels: pixels))
  }
  let overlap = height - step, seam = overlap / 2
  let plan = ReconstructionPlan(axis: .vertical, outputWidth: width, outputHeight: height + 2 * step,
    placements: captures.enumerated().map { CapturePlacement(captureID: $0.element.id, originY: $0.offset * step, width: width, height: height) },
    joints: (0..<2).map { JointDiagnosis(precedingCaptureID: captures[$0].id, followingCaptureID: captures[$0 + 1].id,
      overlapRows: overlap, seamRowInOverlap: seam, outputSeamRow: ($0 + 1) * step + seam,
      normalizedMeanAbsoluteError: 0.001, changedPixelFraction: 0.001, confidence: .strong) })
  return (captures, plan)
}

func adjustment(_ plan: ReconstructionPlan, joint: Int, row: Int) -> SeamAdjustment {
  SeamAdjustment(precedingCaptureID: plan.joints[joint].precedingCaptureID,
    followingCaptureID: plan.joints[joint].followingCaptureID, seamRowInOverlap: row)
}

func oracle(_ captures: [CaptureAsset], boundaries: [Int], origins: [Int], width: Int, height: Int) -> [UInt8] {
  var pixels: [UInt8] = []
  for row in 0..<height {
    let index = boundaries.filter { row >= $0 }.count
    for column in 0..<width {
      let offset = ((row - origins[index]) * width + column) * 4
      pixels += captures[index].image.pixels[offset..<offset + 4]
    }
  }
  return pixels
}
