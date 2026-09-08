import TraktionDomain

/// Diagnostic measurements of the Lab process, not an isolated engine heap
/// or an iOS device memory budget. Sampling does not affect the verdict.
public struct EvaluationPerformanceMetrics: Codable, Equatable, Sendable {
  public let memoryScope: String
  public let platform: String
  public let inputBytes: UInt64
  public let inputPixelCount: UInt64
  public let reconstructionSeconds: Double
  public let peakResidentBytes: UInt64?
  public let inputAmplification: Double?
  public let inputPixelsPerSecond: Double?
  public let memorySamplingError: String?

  static func record(
    inputBytes: UInt64,
    elapsed: Duration,
    sample: () throws -> UInt64 = PeakMemorySampler.peakResidentBytes
  ) -> Self {
    let seconds = Double(elapsed.components.seconds)
      + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
    let pixels = inputBytes / UInt64(RasterImage.channelsPerPixel)
    let peak: UInt64?
    let samplingError: String?
    do {
      let value = try sample()
      if value > 0 {
        peak = value
        samplingError = nil
      } else {
        peak = nil
        samplingError = "Peak resident memory sample was zero."
      }
    } catch {
      peak = nil
      samplingError = String(describing: error)
    }
    #if os(Linux)
      let platform = "linux"
    #elseif canImport(Darwin)
      let platform = "darwin"
    #else
      let platform = "unsupported"
    #endif
    return Self(
      memoryScope: "process-lifetime-high-water-after-reconstruction",
      platform: platform,
      inputBytes: inputBytes,
      inputPixelCount: pixels,
      reconstructionSeconds: seconds,
      peakResidentBytes: peak,
      inputAmplification: inputBytes > 0 ? peak.map { Double($0) / Double(inputBytes) } : nil,
      inputPixelsPerSecond: seconds > 0 && pixels > 0 ? Double(pixels) / seconds : nil,
      memorySamplingError: samplingError
    )
  }
}

/// An advisory only: exceeding it must never change the correctness gate.
public struct EvaluationMemoryAdvisory: Sendable {
  public let maximumInputAmplification: Double

  public enum ValidationError: Error, CustomStringConvertible {
    case invalidRatio

    public var description: String {
      "--max-memory-ratio must be a finite number greater than zero."
    }
  }

  public init(_ value: String) throws {
    guard let ratio = Double(value), ratio.isFinite, ratio > 0 else {
      throw ValidationError.invalidRatio
    }
    maximumInputAmplification = ratio
  }

  public func warnings(in report: EvaluationReport) -> [String] {
    report.cases.compactMap { result in
      guard let ratio = result.performance?.inputAmplification,
        ratio > maximumInputAmplification
      else { return nil }
      return "traktion-lab: warning: \(result.name) process peak/input ratio \(ratio) "
        + "exceeds advisory \(maximumInputAmplification); correctness gate unchanged."
    }
  }
}
