#if canImport(Darwin)
import Darwin
#elseif os(Linux) && canImport(Glibc)
import Glibc
#endif

/// Reads the operating system's process-lifetime resident-memory high-water mark.
///
/// This is not current RSS, an allocation delta, or memory attributable to a
/// single reconstruction. It includes fixtures, earlier cases, and other work
/// performed in this process before the sample. Use a fresh process for each
/// case when comparing isolated measurements.
public enum PeakMemorySampler {
  public enum Failure: Error, Equatable, Sendable, CustomStringConvertible {
    case systemCallFailed(errno: Int32)
    case unsupportedPlatform
    case nonpositiveResidentSize(rawValue: Int64)
    case residentSizeOverflow(rawValue: Int64)

    public var description: String {
      switch self {
      case .systemCallFailed(let errorNumber):
        return "getrusage(RUSAGE_SELF) failed with errno \(errorNumber); peak resident memory is unavailable."
      case .unsupportedPlatform:
        return "Peak resident memory sampling requires Darwin or Linux with Glibc."
      case .nonpositiveResidentSize(let rawValue):
        return "getrusage returned nonpositive ru_maxrss \(rawValue); peak resident memory is unavailable."
      case .residentSizeOverflow(let rawValue):
        return "Converting ru_maxrss \(rawValue) to bytes exceeds UInt64; peak resident memory is unavailable."
      }
    }
  }

  /// Returns `getrusage(RUSAGE_SELF).ru_maxrss`, normalized to bytes.
  /// Throws rather than reporting zero or substituting an estimate.
  public static func peakResidentBytes() throws -> UInt64 {
    #if canImport(Darwin)
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      throw Failure.systemCallFailed(errno: errno)
    }
    // Apple's XNU getrusage(2) specifies bytes on Darwin.
    return try normalize(rawValue: Int64(usage.ru_maxrss), unit: .bytes)
    #elseif os(Linux) && canImport(Glibc)
    var usage = rusage()
    // Glibc imports this selector as an enum, while getrusage takes an Int32.
    guard getrusage(Int32(RUSAGE_SELF.rawValue), &usage) == 0 else {
      throw Failure.systemCallFailed(errno: errno)
    }
    // Linux getrusage(2) specifies KiB, unlike Darwin's byte-valued field.
    return try normalize(rawValue: Int64(usage.ru_maxrss), unit: .kibibytes)
    #else
    throw Failure.unsupportedPlatform
    #endif
  }

  enum Unit {
    case bytes
    case kibibytes
  }

  static func normalize(rawValue: Int64, unit: Unit) throws -> UInt64 {
    guard rawValue > 0 else {
      throw Failure.nonpositiveResidentSize(rawValue: rawValue)
    }
    let multiplier: UInt64 = unit == .bytes ? 1 : 1_024
    let (bytes, overflow) = UInt64(rawValue).multipliedReportingOverflow(by: multiplier)
    guard !overflow else {
      throw Failure.residentSizeOverflow(rawValue: rawValue)
    }
    return bytes
  }
}
