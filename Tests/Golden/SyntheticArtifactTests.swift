import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision
import XCTest

@testable import TraktionLabEvaluation

final class SyntheticArtifactTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "traktion-artifacts-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  private func baseline() throws -> FixtureControlBundle {
    try FixtureControlGenerator.generate(FixtureControlConfiguration(seed: 12001))
  }

  private func manifest(_ caseDirectory: URL) throws -> [String: Any] {
    try XCTUnwrap(
      JSONSerialization.jsonObject(
        with: Data(contentsOf: caseDirectory.appendingPathComponent("manifest.json")))
        as? [String: Any]
    )
  }

  func testFabricatedPixelMismatchRetainsFullBundleAndAbsoluteDifferences() throws {
    let root = try directory()
    let bundle = try baseline()
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    var pixels = result.image.pixels
    pixels[0] ^= 127
    let changed = try RasterImage(
      width: result.image.width, height: result.image.height, pixels: pixels)
    let fabricated = ReconstructionResult(plan: result.plan, image: changed)
    let assessment = EvaluationHarness.assess(
      name: "fabricated", bundle: bundle, outcome: .reconstructed(fabricated),
      deterministic: true, milliseconds: 0
    )
    XCTAssertEqual(assessment.verdict, .falseSafe)
    // Reverse the supplied array to prove diagnostics resolve IDs, not input indices.
    try SyntheticArtifactWriter.write(
      caseName: "fabricated", expected: bundle.source, captures: bundle.captures.reversed(),
      outcome: .reconstructed(fabricated), assessment: assessment, directory: root
    )
    let output = root.appendingPathComponent("fabricated")
    XCTAssertEqual(
      try PNGCodec.decodeOpaqueRGBA8(from: output.appendingPathComponent("expected.png")),
      bundle.source)
    XCTAssertEqual(
      try PNGCodec.decodeOpaqueRGBA8(from: output.appendingPathComponent("actual.png")), changed)
    let difference = try PNGCodec.decodeOpaqueRGBA8(
      from: output.appendingPathComponent("difference.png"))
    XCTAssertEqual(difference.width, changed.width)
    XCTAssertEqual(difference.height, changed.height)
    for offset in stride(from: 0, to: difference.pixels.count, by: 4) {
      for channel in 0..<3 {
        XCTAssertEqual(
          difference.pixels[offset + channel],
          UInt8(
            abs(Int(bundle.source.pixels[offset + channel]) - Int(changed.pixels[offset + channel]))
          )
        )
      }
      XCTAssertEqual(difference.pixels[offset + 3], 255)
    }
    let record = try manifest(output)
    XCTAssertEqual(record["provenance"] as? String, "synthetic-only")
    XCTAssertEqual((record["assessment"] as? [String: Any])?["verdict"] as? String, "false-safe")
    let recordedPlan = try XCTUnwrap(record["plan"])
    XCTAssertEqual(
      try JSONDecoder().decode(
        ReconstructionPlan.self, from: JSONSerialization.data(withJSONObject: recordedPlan)),
      result.plan
    )
    for (index, joint) in result.plan.joints.enumerated() {
      let stem = String(format: "joint-%03d", index + 1)
      let jointDirectory = output.appendingPathComponent("joints")
      let json = try XCTUnwrap(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: jointDirectory.appendingPathComponent("\(stem).json")))
          as? [String: Any]
      )
      let diagnosis = try XCTUnwrap(json["diagnosis"])
      XCTAssertEqual(
        try JSONDecoder().decode(
          JointDiagnosis.self, from: JSONSerialization.data(withJSONObject: diagnosis)), joint
      )
      let expectedDifference = try ReconstructionEngine().differenceImage(
        preceding: bundle.captures[index], following: bundle.captures[index + 1], joint: joint
      )
      XCTAssertEqual(
        try PNGCodec.decodeOpaqueRGBA8(
          from: jointDirectory.appendingPathComponent("\(stem)-difference.png")),
        expectedDifference
      )
    }
  }

  func testHarnessWritesFalseSafeAndFalseWarningWithoutInventingMissingOutput() throws {
    let root = try directory()
    let report = try EvaluationHarness.evaluate(
      [
        EvaluationCase(
          name: "false-safe", configuration: FixtureControlConfiguration(seed: 12002),
          ordering: OrderingCase(
            permutation: [0, 1, 2], expected: .fail(code: "sequenceOrderNotFound"))
        ),
        EvaluationCase(
          name: "false-warning", configuration: FixtureControlConfiguration(seed: 12003),
          engineAxis: .horizontal),
      ], artifacts: EvaluationArtifactOptions(directory: root))
    XCTAssertFalse(report.summary.isAcceptable)
    XCTAssertEqual(report.cases.map(\.verdict), [.falseSafe, .falseWarning])
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("false-safe/actual.png").path))
    let failure = root.appendingPathComponent("false-warning")
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: failure.path).sorted(),
      ["expected.png", "manifest.json"])
    let record = try manifest(failure)
    XCTAssertEqual(record["status"] as? String, "failed")
    let unavailable = try XCTUnwrap(record["unavailableArtifacts"] as? [String: String])
    XCTAssertEqual(Set(unavailable.keys), Set(["actual.png", "difference.png", "joints"]))
    let failureJSON = try XCTUnwrap(record["reconstructionFailure"])
    XCTAssertEqual(
      try JSONDecoder().decode(
        ReconstructionFailure.self, from: JSONSerialization.data(withJSONObject: failureJSON)),
      .unsupportedAxis(.horizontal)
    )
  }

  func testPassingCasesWriteNothingUnlessAllArtifactsIsEnabled() throws {
    let root = try directory()
    let cases = [
      EvaluationCase(name: "baseline", configuration: FixtureControlConfiguration(seed: 12004)),
      EvaluationCase(
        name: "duplicate",
        configuration: FixtureControlConfiguration(seed: 12005, variant: .duplicateCapture)),
    ]
    let report = try EvaluationHarness.evaluate(
      cases, artifacts: EvaluationArtifactOptions(directory: root))
    XCTAssertTrue(report.summary.isAcceptable)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    let all = try EvaluationHarness.evaluate(
      cases, artifacts: EvaluationArtifactOptions(directory: root, includePassingCases: true))
    XCTAssertTrue(all.summary.isAcceptable)
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(),
      ["baseline", "duplicate"])
    XCTAssertEqual(
      try manifest(root.appendingPathComponent("duplicate"))["status"] as? String, "failed")
  }

  func testDimensionMismatchKeepsOriginalRastersAndMarksCommonDifferenceExtent() throws {
    let root = try directory()
    let bundle = try baseline()
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    let width = result.image.width - 1
    let height = result.image.height - 2
    var pixels: [UInt8] = []
    for row in 0..<height {
      let start = row * result.image.rowByteCount
      pixels.append(contentsOf: result.image.pixels[start..<(start + width * 4)])
    }
    let smaller = try RasterImage(width: width, height: height, pixels: pixels)
    try SyntheticArtifactWriter.write(
      caseName: "smaller", expected: bundle.source, captures: bundle.captures,
      outcome: .reconstructed(ReconstructionResult(plan: result.plan, image: smaller)),
      directory: root
    )
    let output = root.appendingPathComponent("smaller")
    XCTAssertEqual(
      try PNGCodec.decodeOpaqueRGBA8(from: output.appendingPathComponent("expected.png")),
      bundle.source)
    XCTAssertEqual(
      try PNGCodec.decodeOpaqueRGBA8(from: output.appendingPathComponent("actual.png")), smaller)
    let difference = try PNGCodec.decodeOpaqueRGBA8(
      from: output.appendingPathComponent("difference.png"))
    XCTAssertEqual(difference.width, width)
    XCTAssertEqual(difference.height, height)
    let record = try manifest(output)
    XCTAssertEqual(
      record["differenceExtent"] as? [String: Int], ["width": width, "height": height])
    XCTAssertEqual(record["differenceOrigin"] as? String, "top-left")
  }

  func testGoldenHelperWritesOnlyWhenEnabledAndFailed() throws {
    let root = try directory()
    let bundle = try baseline()
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    let record = GoldenArtifactRecord(
      caseName: "golden", expected: bundle.source, captures: bundle.captures,
      outcome: .reconstructed(result)
    )
    try record.writeIfFailed(false, directory: root)
    try record.writeIfFailed(true, directory: nil)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    try record.writeIfFailed(true, directory: root)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("golden/manifest.json").path))
    XCTAssertThrowsError(
      try record.writeIfFailed(true, directory: root), "publication failures must reach XCTest")
  }

  func testExistingOutputsAndSymlinkTargetsAreNeverOverwritten() throws {
    let root = try directory()
    let original = root.appendingPathComponent("original")
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    let sentinel = original.appendingPathComponent("source.txt")
    try Data("preserve original".utf8).write(to: sentinel)
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("linked"), withDestinationURL: original)
    let bundle = try baseline()
    for caseName in ["original", "linked"] {
      XCTAssertThrowsError(
        try SyntheticArtifactWriter.write(
          caseName: caseName, expected: bundle.source, captures: bundle.captures,
          outcome: .failed(.unsupportedAxis(.horizontal)), directory: root
        ))
    }
    XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve original".utf8))
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: original.path), ["source.txt"])
  }

  func testWriteErrorsAreLoudAndPartialCaseIsRemoved() throws {
    let root = try directory()
    let bundle = try baseline()
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertThrowsError(
      try SyntheticArtifactWriter.write(
        caseName: "bad-joints", expected: bundle.source, captures: [],
        outcome: .reconstructed(result), directory: root
      ))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    let blocked = root.appendingPathComponent("file")
    try Data("untouched".utf8).write(to: blocked)
    XCTAssertThrowsError(
      try SyntheticArtifactWriter.write(
        caseName: "unwritable", expected: bundle.source, captures: bundle.captures,
        outcome: .reconstructed(result), directory: blocked
      ))
    XCTAssertEqual(try Data(contentsOf: blocked), Data("untouched".utf8))
  }

  func testUnsafeAndDuplicateNamesFailBeforeAnyArtifactsAreWritten() throws {
    let root = try directory()
    let bundle = try baseline()
    for name in ["", ".", "..", "../escape", "/absolute", "nested/name", "back\\slash"] {
      XCTAssertThrowsError(
        try SyntheticArtifactWriter.write(
          caseName: name, expected: bundle.source, captures: bundle.captures,
          outcome: .failed(.unsupportedAxis(.horizontal)), directory: root
        ))
    }
    let repeated = EvaluationCase(
      name: "repeat", configuration: FixtureControlConfiguration(seed: 12006))
    XCTAssertThrowsError(
      try EvaluationHarness.evaluate(
        [repeated, repeated],
        artifacts: EvaluationArtifactOptions(directory: root, includePassingCases: true)
      ))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
  }

  func testBundleContentsAreDeterministicAndUnexpectedErrorsRemainVisible() throws {
    let first = try directory()
    let second = try directory()
    let bundle = try baseline()
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    for root in [first, second] {
      try SyntheticArtifactWriter.write(
        caseName: "same", expected: bundle.source, captures: bundle.captures,
        outcome: .reconstructed(result), directory: root
      )
    }
    let files = [
      "expected.png", "actual.png", "difference.png", "manifest.json", "joints/joint-001.json",
      "joints/joint-001-difference.png",
    ]
    for file in files {
      XCTAssertEqual(
        try Data(contentsOf: first.appendingPathComponent("same/\(file)")),
        try Data(contentsOf: second.appendingPathComponent("same/\(file)"))
      )
    }
    try SyntheticArtifactWriter.write(
      caseName: "unexpected", expected: bundle.source, captures: bundle.captures,
      outcome: .unexpectedError("synthetic injected error"), directory: first
    )
    let record = try manifest(first.appendingPathComponent("unexpected"))
    XCTAssertEqual(record["unexpectedError"] as? String, "synthetic injected error")
    XCTAssertEqual(record["status"] as? String, "unexpected-error")
  }
}
