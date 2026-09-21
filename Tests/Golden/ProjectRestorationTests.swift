import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
import XCTest

/// Exercises Core directly: no file container, UI model or persistence service.
final class ProjectRestorationTests: XCTestCase {
  func testExactAutomaticProjectRestoresPixelsEvidenceAndEmptyHistory() throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let automatic = try ReconstructionEngine().reconstruct(fixture.sequence)
    let restored = try ProjectRestorer().restore(captures: fixture.captures,
      automaticPlan: automatic.plan, committedPlan: automatic.plan)
    XCTAssertEqual(restored.result.image, fixture.source)
    XCTAssertEqual(restored.result.plan, automatic.plan)
    XCTAssertEqual(restored.document.originalPlan, automatic.plan)
    XCTAssertEqual(restored.document.plan, automatic.plan)
    XCTAssertFalse(restored.document.isModified)
    XCTAssertFalse(restored.document.canUndo)
    XCTAssertFalse(restored.document.canRedo)
  }

  func testStrongEditedProjectSelectsIndependentOriginalPixelsAndPreservesEvidence() throws {
    let captures = try nearExactOriginals()
    let originalPixels = captures.map(\.image)
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    XCTAssertEqual(automatic.plan.joints[0].confidence, .strong)
    XCTAssertEqual(automatic.plan.placements.map(\.originY), [0, 10])
    XCTAssertEqual(automatic.plan.joints[0].overlapRows, 20)
    let committed = changingJoint(automatic.plan, seam: 0)
    let restored = try ProjectRestorer().restore(captures: captures,
      automaticPlan: automatic.plan, committedPlan: committed)
    XCTAssertEqual(restored.result, automatic)
    XCTAssertEqual(restored.document.originalPlan, automatic.plan)
    XCTAssertEqual(restored.document.plan, committed)
    XCTAssertTrue(restored.document.isModified)
    XCTAssertFalse(restored.document.canUndo)
    XCTAssertFalse(restored.document.canRedo)
    let edited = try PlannedRasterRenderer(plan: restored.document.plan, captures: captures)
      .renderPreview(width: 40, height: 40, isCancelled: { false })
    // The chosen boundary is row 10: exactly ten first-source rows, then all
    // thirty second-source rows, including its independently marked first pixel.
    let expected = Array(captures[0].image.pixels.prefix(10 * 40 * 4)) + captures[1].image.pixels
    XCTAssertEqual(edited.pixels, expected)
    XCTAssertNotEqual(edited, automatic.image)
    XCTAssertEqual(captures.map(\.image), originalPixels)
  }

  func testMatchingForgeryInBothSavedPlansCannotReplaceRecomputedEvidence() throws {
    let captures = try nearExactOriginals()
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    let forgedPlans = [
      changingJoint(automatic.plan, confidence: .exact),
      changingJoint(automatic.plan, error: 0.001),
      changingJoint(automatic.plan, changedFraction: 0.001),
      changingJoint(automatic.plan, overlap: 19),
    ]
    for forged in forgedPlans {
      XCTAssertNotEqual(forged, automatic.plan)
      // Both saved plans agree. Only recomputation from originals exposes this.
      XCTAssertThrowsError(try ProjectRestorer().restore(captures: captures,
        automaticPlan: forged, committedPlan: forged)) {
        XCTAssertEqual($0 as? ProjectRestorationFailure, .invalidEvidence)
      }
    }
  }

  func testCommittedEvidenceInvalidSeamAndPlacementAreRefusedAfterAutomaticReplay() throws {
    let captures = try nearExactOriginals()
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    var changedPlacements = automatic.plan.placements
    let placement = changedPlacements[1]
    changedPlacements[1] = CapturePlacement(captureID: placement.captureID,
      originY: placement.originY + 1, width: placement.width, height: placement.height)
    let misplaced = ReconstructionPlan(axis: automatic.plan.axis,
      outputWidth: automatic.plan.outputWidth, outputHeight: automatic.plan.outputHeight,
      placements: changedPlacements, joints: automatic.plan.joints)
    for committed in [
      changingJoint(automatic.plan, confidence: .exact),
      changingJoint(automatic.plan, error: 0.001),
      changingJoint(automatic.plan, changedFraction: 0.001),
      changingJoint(automatic.plan, seam: -1),
      changingJoint(automatic.plan, seam: 21), misplaced,
    ] {
      XCTAssertThrowsError(try ProjectRestorer().restore(captures: captures,
        automaticPlan: automatic.plan, committedPlan: committed)) {
        XCTAssertEqual($0 as? ProjectRestorationFailure, .invalidEvidence)
      }
    }
  }

  func testChangedOriginalOverlapAndEngineRefusalAreTypedInvalidEvidence() throws {
    let captures = try nearExactOriginals()
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    var changedPixels = captures[0].image.pixels
    changedPixels[12 * 40 * 4] ^= 1
    let changed = CaptureAsset(id: captures[0].id, sourceName: captures[0].sourceName,
      image: try RasterImage(width: 40, height: 30, pixels: changedPixels))
    for originals in [[changed, captures[1]], [captures[0], captures[0]]] {
      XCTAssertThrowsError(try ProjectRestorer().restore(captures: originals,
        automaticPlan: automatic.plan, committedPlan: automatic.plan)) {
        XCTAssertEqual($0 as? ProjectRestorationFailure, .invalidEvidence)
      }
    }
  }

  func testCancellationWinsBeforeEngineAndBeforeSavedEvidenceAcceptance() throws {
    let captures = try nearExactOriginals()
    let automatic = try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    XCTAssertThrowsError(try ProjectRestorer().restore(captures: [],
      automaticPlan: automatic.plan, committedPlan: automatic.plan, isCancelled: { true })) {
      XCTAssertEqual($0 as? ProjectRestorationFailure, .cancelled)
    }
    let cancellation = RestorationCancellationProbe()
    let forged = changingJoint(automatic.plan, confidence: .exact)
    XCTAssertThrowsError(try ProjectRestorer().restore(captures: captures,
      automaticPlan: forged, committedPlan: forged, isCancelled: { cancellation.check() })) {
      XCTAssertEqual($0 as? ProjectRestorationFailure, .cancelled)
    }
    XCTAssertEqual(cancellation.checks, 2)
  }
}

private func nearExactOriginals() throws -> [CaptureAsset] {
  let source = try SyntheticFixtureFactory.document(width: 40, height: 40, seed: 0x53414D50)
  let rowBytes = 40 * 4
  var following = Array(source.pixels[10 * rowBytes..<40 * rowBytes])
  following[0] ^= 1
  return [
    CaptureAsset(id: "original-first", sourceName: "first.png",
      image: try RasterImage(width: 40, height: 30, pixels: Array(source.pixels.prefix(30 * rowBytes)))),
    CaptureAsset(id: "original-second", sourceName: "second.png",
      image: try RasterImage(width: 40, height: 30, pixels: following)),
  ]
}

private func changingJoint(_ plan: ReconstructionPlan, seam: Int? = nil,
  confidence: JointConfidence? = nil, error: Double? = nil,
  changedFraction: Double? = nil, overlap: Int? = nil) -> ReconstructionPlan {
  let joint = plan.joints[0]
  let row = seam ?? joint.seamRowInOverlap
  let changed = JointDiagnosis(precedingCaptureID: joint.precedingCaptureID,
    followingCaptureID: joint.followingCaptureID, overlapRows: overlap ?? joint.overlapRows,
    seamRowInOverlap: row, outputSeamRow: plan.placements[1].originY + row,
    normalizedMeanAbsoluteError: error ?? joint.normalizedMeanAbsoluteError,
    changedPixelFraction: changedFraction ?? joint.changedPixelFraction,
    confidence: confidence ?? joint.confidence)
  return ReconstructionPlan(axis: plan.axis, outputWidth: plan.outputWidth,
    outputHeight: plan.outputHeight, placements: plan.placements, joints: [changed])
}

private final class RestorationCancellationProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var checks: Int { lock.withLock { count } }
  func check() -> Bool { lock.withLock { count += 1; return count == 2 } }
}
