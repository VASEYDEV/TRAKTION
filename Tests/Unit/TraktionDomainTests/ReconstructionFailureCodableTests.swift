import Foundation
import XCTest

@testable import TraktionDomain

final class ReconstructionFailureCodableTests: XCTestCase {
  private let allCases: [ReconstructionFailure] = [
    .unsupportedAxis(.horizontal),
    .captureCountOutOfRange(actual: 1, allowed: 2...10),
    .incompatibleDimensions(expectedWidth: 64, actualWidth: 72, captureID: "capture-002"),
    .duplicateCapture(preceding: "capture-001", following: "capture-003"),
    .insufficientOverlap(preceding: "capture-001", following: "capture-002", minimumRows: 8),
    .ambiguousOverlap(preceding: "capture-001", following: "capture-002", candidateRows: [8, 20]),
    .sequenceOrderNotFound(captureIDs: ["capture-001", "capture-002"]),
    .ambiguousSequenceOrder(candidateOrders: [
      ["capture-001", "capture-002"], ["capture-002", "capture-001"],
    ]),
    .resourceLimitExceeded(reason: "sample budget exceeded"),
    .outputDimensionsOverflow,
    .invalidPlan(reason: "capture segment out of range"),
  ]

  func testEveryCaseRoundTripsThroughCodable() throws {
    for failure in allCases {
      let encoded = try JSONEncoder().encode(failure)
      let decoded = try JSONDecoder().decode(ReconstructionFailure.self, from: encoded)
      XCTAssertEqual(decoded, failure)
    }
  }

  func testEncodingIsDeterministic() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for failure in allCases {
      XCTAssertEqual(try encoder.encode(failure), try encoder.encode(failure))
    }
  }

  func testFailureCodesAreStableWireContracts() {
    XCTAssertEqual(
      allCases.map(\.code),
      [
        "unsupportedAxis", "captureCountOutOfRange", "incompatibleDimensions",
        "duplicateCapture", "insufficientOverlap", "ambiguousOverlap",
        "sequenceOrderNotFound", "ambiguousSequenceOrder",
        "resourceLimitExceeded", "outputDimensionsOverflow", "invalidPlan",
      ]
    )
  }
}
