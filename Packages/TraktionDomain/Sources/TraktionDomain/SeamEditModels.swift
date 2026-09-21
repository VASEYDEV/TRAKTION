/// Manual selection changes only which original supplies pixels in proven overlap.
public struct SeamAdjustment: Equatable, Codable, Sendable {
  public let precedingCaptureID: CaptureID
  public let followingCaptureID: CaptureID
  public let seamRowInOverlap: Int

  public init(precedingCaptureID: CaptureID, followingCaptureID: CaptureID, seamRowInOverlap: Int) {
    self.precedingCaptureID = precedingCaptureID
    self.followingCaptureID = followingCaptureID
    self.seamRowInOverlap = seamRowInOverlap
  }
}

public enum SeamEditingFailure: Error, Equatable, Sendable {
  case invalidPlan
  case unsupportedEvidence
  case invalidJoint
  case outsideProvenOverlap
  case crossingSeams
  case invalidRegion
  case resourceLimit
  case cancelled
}

/// Sampling coordinates are original output pixels. Scale is display pixels per source pixel.
public struct RasterSamplingRegion: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public let x: Double
  public let y: Double
  public let scale: Double

  public init(width: Int, height: Int, x: Double, y: Double, scale: Double) {
    self.width = width; self.height = height; self.x = x; self.y = y; self.scale = scale
  }
}
