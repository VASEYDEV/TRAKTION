public struct ReconstructionSettings: Equatable, Sendable {
  public var minimumOverlapRows: Int
  public var maximumNormalizedMeanAbsoluteError: Double
  public var maximumChangedPixelFraction: Double
  public var changedChannelThreshold: UInt8
  public var sampledRows: Int
  public var sampledColumns: Int
  public var candidateLimit: Int
  public var ambiguityTolerance: Double

  public init(
    minimumOverlapRows: Int = 8,
    maximumNormalizedMeanAbsoluteError: Double = 0.01,
    maximumChangedPixelFraction: Double = 0.02,
    changedChannelThreshold: UInt8 = 4,
    sampledRows: Int = 24,
    sampledColumns: Int = 64,
    candidateLimit: Int = 12,
    ambiguityTolerance: Double = 0.000_001
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
    self.ambiguityTolerance = max(0, ambiguityTolerance)
  }
}
