import XCTest

@testable import TraktionLabEvaluation

final class PeakMemorySamplerTests: XCTestCase {
  func testDarwinByteValuesRemainBytes() throws {
    XCTAssertEqual(try PeakMemorySampler.normalize(rawValue: 1, unit: .bytes), 1)
    XCTAssertEqual(
      try PeakMemorySampler.normalize(rawValue: 98_765_432, unit: .bytes), 98_765_432
    )
    XCTAssertEqual(
      try PeakMemorySampler.normalize(rawValue: Int64.max, unit: .bytes), UInt64(Int64.max)
    )
  }

  func testLinuxKibibytesConvertWithoutDecimalRounding() throws {
    XCTAssertEqual(try PeakMemorySampler.normalize(rawValue: 1, unit: .kibibytes), 1_024)
    XCTAssertEqual(
      try PeakMemorySampler.normalize(rawValue: 96_451, unit: .kibibytes), 98_765_824
    )
    let largestConvertible = Int64(UInt64.max / 1_024)
    XCTAssertEqual(
      try PeakMemorySampler.normalize(rawValue: largestConvertible, unit: .kibibytes),
      UInt64.max - 1_023
    )
  }

  func testNonpositiveReadingsFailForBothPlatformUnits() {
    for unit in [PeakMemorySampler.Unit.bytes, .kibibytes] {
      for rawValue: Int64 in [0, -1, Int64.min] {
        XCTAssertThrowsError(try PeakMemorySampler.normalize(rawValue: rawValue, unit: unit)) {
          XCTAssertEqual(
            $0 as? PeakMemorySampler.Failure, .nonpositiveResidentSize(rawValue: rawValue)
          )
        }
      }
    }
  }

  func testKibibyteOverflowThrowsInsteadOfTrappingOrWrapping() {
    let firstOverflowing = Int64(UInt64.max / 1_024) + 1
    for rawValue in [firstOverflowing, Int64.max] {
      XCTAssertThrowsError(
        try PeakMemorySampler.normalize(rawValue: rawValue, unit: .kibibytes)
      ) {
        XCTAssertEqual(
          $0 as? PeakMemorySampler.Failure, .residentSizeOverflow(rawValue: rawValue)
        )
      }
    }
  }

  func testRealProcessSamplesArePositiveAndNeverDecrease() throws {
    #if canImport(Darwin) || (os(Linux) && canImport(Glibc))
    let first = try PeakMemorySampler.peakResidentBytes()
    let second = try PeakMemorySampler.peakResidentBytes()
    XCTAssertGreaterThan(first, 0)
    XCTAssertGreaterThanOrEqual(second, first)
    #else
    XCTAssertThrowsError(try PeakMemorySampler.peakResidentBytes()) {
      XCTAssertEqual($0 as? PeakMemorySampler.Failure, .unsupportedPlatform)
    }
    #endif
  }

  func testFailuresExplainWhyMeasurementIsUnavailable() {
    XCTAssertTrue(PeakMemorySampler.Failure.systemCallFailed(errno: 22).description.contains("errno 22"))
    XCTAssertTrue(PeakMemorySampler.Failure.unsupportedPlatform.description.contains("Darwin or Linux"))
    XCTAssertTrue(
      PeakMemorySampler.Failure.nonpositiveResidentSize(rawValue: -1).description.contains("ru_maxrss -1")
    )
    XCTAssertTrue(
      PeakMemorySampler.Failure.residentSizeOverflow(rawValue: Int64.max).description.contains("exceeds UInt64")
    )
  }
}
