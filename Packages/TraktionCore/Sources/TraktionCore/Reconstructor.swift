import Foundation
import TraktionDomain
import TraktionVision

public struct ReconstructionSettings: Equatable, Sendable {
  public var minimumOverlapRows: Int
  public var maximumMeanAbsoluteError: Double
  public var ambiguityTolerance: Double
  public init(
    minimumOverlapRows: Int = 2, maximumMeanAbsoluteError: Double = 1.0,
    ambiguityTolerance: Double = 0.000_001
  ) {
    self.minimumOverlapRows = minimumOverlapRows
    self.maximumMeanAbsoluteError = maximumMeanAbsoluteError
    self.ambiguityTolerance = ambiguityTolerance
  }
}

public struct ReconstructionOutput: Sendable {
  public let image: PixelImage
  public let plan: ReconstructionPlan
  public let candidates: [[OverlapCandidate]]
}

public struct Reconstructor: Sendable {
  public let settings: ReconstructionSettings
  public init(settings: ReconstructionSettings = .init()) { self.settings = settings }

  public func reconstruct(images: [(asset: CaptureAsset, image: PixelImage)]) throws
    -> ReconstructionOutput
  {
    guard (2...10).contains(images.count) else {
      throw ReconstructionFailure.invalidCaptureCount(actual: images.count)
    }
    let expectedWidth = images[0].image.width
    for item in images where item.image.width != expectedWidth {
      throw ReconstructionFailure.incompatibleDimensions(
        expectedWidth: expectedWidth, actualWidth: item.image.width, captureID: item.asset.id)
    }
    var joints = [JointDiagnosis]()
    var allCandidates = [[OverlapCandidate]]()
    for index in 0..<(images.count - 1) {
      let upper = images[index]
      let lower = images[index + 1]
      if upper.image == lower.image {
        throw ReconstructionFailure.duplicateCapture(captureID: lower.asset.id)
      }
      let candidates = scoreCandidates(upper.image, lower.image)
      allCandidates.append(candidates)
      guard
        let best = candidates.filter({ $0.meanAbsoluteError <= settings.maximumMeanAbsoluteError })
          .min(by: candidateOrder)
      else {
        throw ReconstructionFailure.insufficientOverlap(
          upperCaptureID: upper.asset.id, lowerCaptureID: lower.asset.id)
      }
      let equallyPlausible = candidates.filter {
        $0.rows != best.rows && $0.meanAbsoluteError <= settings.maximumMeanAbsoluteError
          && abs($0.meanAbsoluteError - best.meanAbsoluteError) <= settings.ambiguityTolerance
      }
      if equallyPlausible.contains(where: {
        abs($0.rows - best.rows) >= settings.minimumOverlapRows
      }) {
        throw ReconstructionFailure.ambiguousOverlap(
          upperCaptureID: upper.asset.id, lowerCaptureID: lower.asset.id)
      }
      joints.append(
        JointDiagnosis(
          upperCaptureID: upper.asset.id, lowerCaptureID: lower.asset.id,
          overlapRows: best.rows, seamRowInOverlap: best.rows / 2,
          confidence: best.meanAbsoluteError == 0 ? .exact : .strong,
          meanAbsoluteError: best.meanAbsoluteError, differingPixels: best.differingPixels
        ))
    }
    let outputHeight =
      images.map(\.image.height).reduce(0, +) - joints.map(\.overlapRows).reduce(0, +)
    let plan = ReconstructionPlan(
      axis: .vertical, captures: images.map(\.asset), joints: joints, outputWidth: expectedWidth,
      outputHeight: outputHeight)
    return ReconstructionOutput(
      image: compose(
        images: images.map(\.image), joints: joints, width: expectedWidth, height: outputHeight),
      plan: plan, candidates: allCandidates)
  }

  private func scoreCandidates(_ upper: PixelImage, _ lower: PixelImage) -> [OverlapCandidate] {
    let maximum = min(upper.height, lower.height)
    guard maximum >= settings.minimumOverlapRows else { return [] }
    return (settings.minimumOverlapRows...maximum).map { rows in
      let a = upper.rows((upper.height - rows)..<upper.height)
      let b = lower.rows(0..<rows)
      var total = 0
      var differing = 0
      for (left, right) in zip(a, b) {
        total += abs(Int(left) - Int(right))
        if left != right { differing += 1 }
      }
      return OverlapCandidate(
        rows: rows, meanAbsoluteError: Double(total) / Double(a.count), differingPixels: differing)
    }
  }

  private func candidateOrder(_ lhs: OverlapCandidate, _ rhs: OverlapCandidate) -> Bool {
    if abs(lhs.meanAbsoluteError - rhs.meanAbsoluteError) > settings.ambiguityTolerance {
      return lhs.meanAbsoluteError < rhs.meanAbsoluteError
    }
    return lhs.rows > rhs.rows
  }

  private func compose(images: [PixelImage], joints: [JointDiagnosis], width: Int, height: Int)
    -> PixelImage
  {
    var pixels = images[0].rgba
    for index in joints.indices {
      let joint = joints[index]
      let lower = images[index + 1]
      let rowsToRemove = joint.overlapRows - joint.seamRowInOverlap
      pixels.removeLast(rowsToRemove * width * 4)
      pixels += lower.rows(joint.seamRowInOverlap..<lower.height)
    }
    return PixelImage(width: width, height: height, rgba: pixels)
  }
}
