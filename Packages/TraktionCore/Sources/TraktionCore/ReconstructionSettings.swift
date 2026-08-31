public struct ReconstructionSettings: Equatable, Sendable {
  public let minimumOverlapRows: Int
  public let maximumNormalizedMeanAbsoluteError: Double
  public let maximumChangedPixelFraction: Double
  public let changedChannelThreshold: UInt8
  public let sampledRows: Int
  public let sampledColumns: Int
  public let candidateLimit: Int
  public let maximumCapturePixels: Int
  public let maximumTotalInputPixels: Int
  public let maximumOutputPixels: Int
  public let maximumOverlapSearchRows: Int
  public let maximumSampleComparisonsPerJoint: Int
  public let maximumFullComparisonPixelsPerJoint: Int

  public init(
    minimumOverlapRows: Int = 8,
    maximumNormalizedMeanAbsoluteError: Double = 0.01,
    maximumChangedPixelFraction: Double = 0.02,
    changedChannelThreshold: UInt8 = 4,
    sampledRows: Int = 24,
    sampledColumns: Int = 64,
    candidateLimit: Int = 12,
    maximumCapturePixels: Int = 16_777_216,
    maximumTotalInputPixels: Int = 67_108_864,
    maximumOutputPixels: Int = 67_108_864,
    maximumOverlapSearchRows: Int = 16_384,
    maximumSampleComparisonsPerJoint: Int = 33_554_432,
    maximumFullComparisonPixelsPerJoint: Int = 33_554_432
  ) {
    self.minimumOverlapRows = max(1, minimumOverlapRows)
    self.maximumNormalizedMeanAbsoluteError = max(
      0,
      maximumNormalizedMeanAbsoluteError
    )
    self.maximumChangedPixelFraction = max(0, maximumChangedPixelFraction)
    self.changedChannelThreshold = changedChannelThreshold
    self.sampledRows = max(2, sampledRows)
    self.sampledColumns = max(2, sampledColumns)
    self.candidateLimit = max(2, candidateLimit)
    self.maximumCapturePixels = max(1, maximumCapturePixels)
    self.maximumTotalInputPixels = max(1, maximumTotalInputPixels)
    self.maximumOutputPixels = max(1, maximumOutputPixels)
    self.maximumOverlapSearchRows = max(1, maximumOverlapSearchRows)
    self.maximumSampleComparisonsPerJoint = max(
      1,
      maximumSampleComparisonsPerJoint
    )
    self.maximumFullComparisonPixelsPerJoint = max(
      1,
      maximumFullComparisonPixelsPerJoint
    )
  }
}
