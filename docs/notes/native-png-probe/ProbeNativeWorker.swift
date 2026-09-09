import FixtureForgeKit
import Foundation
import Glibc
import TraktionDomain
import TraktionLabEvaluation
@testable import TraktionUI

// Linux-only diagnostics for the production worker and exact bounded-preview helper.
// Uses synchronous execution because this cloud host cannot monitor long-lived dispatch
// worker threads. File generation is separate. No model scheduler, CGImage, ImageIO,
// simulator or physical-device claim is made.
@main
struct ProbeNativeWorker {
  static func main() throws {
    guard CommandLine.arguments.count == 3 else { throw ProbeFailure.invalidArguments }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let output = URL(fileURLWithPath: CommandLine.arguments[2])
    let truth = try JSONDecoder().decode(
      FixtureGroundTruth.self, from: Data(contentsOf: directory.appendingPathComponent("fixture.json"))
    )
    let urls = truth.captures.map { directory.appendingPathComponent($0.fileName) }
    let worker = NativeWorkspaceWorker()
    let before = try MemorySample.read()
    let importStart = ContinuousClock.now
    let captures = try worker.importCaptures(from: urls, retainedRasterBytes: 0, isCancelled: { false })
    var thumbnails: [CaptureID: RasterImage] = [:]
    for asset in captures {
      thumbnails[asset.id] = try NativeRasterPreview.make(
        asset.image, maximumDimension: NativeRasterPreview.thumbnailDimension,
        maximumPixels: NativeRasterPreview.thumbnailDimension * NativeRasterPreview.thumbnailDimension,
        isCancelled: { false }
      )
    }
    let importSeconds = seconds(importStart.duration(to: .now))
    let afterImport = try MemorySample.read()
    guard captures.count == urls.count else { throw ProbeFailure.pipeline("Wrong capture count") }
    let inputBytes = captures.reduce(0) { $0 + $1.image.pixels.count }
    let thumbnailBytes = thumbnails.values.reduce(0) { $0 + $1.pixels.count }
    let admittedBytes = inputBytes * 2 + thumbnailBytes * 2
      + min(inputBytes, NativeRasterPreview.maximumResultPixels * 4) * 2
    guard admittedBytes <= 268_435_456 else { throw ProbeFailure.pipeline("Workspace admission refused") }
    let reconstructionStart = ContinuousClock.now
    let result = try worker.reconstruct(captures)
    let preview = try NativeRasterPreview.make(
      result.image, maximumDimension: NativeRasterPreview.maximumResultDimension,
      maximumPixels: NativeRasterPreview.maximumResultPixels, isCancelled: { false }
    )
    let reconstructionSeconds = seconds(reconstructionStart.duration(to: .now))
    // Keep every raster alive exactly as the workspace does when displaying its result.
    let afterReconstruction = try withExtendedLifetime((captures, thumbnails, result, preview)) {
      try MemorySample.read()
    }
    let actualFingerprint = fingerprint(result.image)
    guard actualFingerprint == truth.sourcePixelFingerprint,
      result.image.width == truth.sourceWidth, result.image.height == truth.sourceHeight,
      result.plan.joints.map(\.overlapRows) == truth.expectedOverlaps
    else { throw ProbeFailure.pipeline("Reconstruction differs from generated source truth") }
    let report = ProbeReport(
      platform: "Linux x86_64; Swift 6.0.3 release; synchronous NativeWorkspaceWorker + NativeRasterPreview; no SwiftUI/CGImage/model scheduler",
      caseName: truth.sourceID,
      captureCount: captures.count,
      inputBytes: inputBytes,
      thumbnailBytes: thumbnailBytes,
      resultBytes: result.image.pixels.count,
      resultPreviewBytes: preview.pixels.count,
      ownedRasterBytesAfterReconstruction: inputBytes + thumbnailBytes + result.image.pixels.count + preview.pixels.count,
      reconstructionAdmissionBytes: inputBytes * 2 + thumbnailBytes * 2 + min(inputBytes, 1_048_576 * 4) * 2,
      ownedRasterBudgetBytes: 268_435_456,
      outputWidth: result.image.width,
      outputHeight: result.image.height,
      jointCount: result.plan.joints.count,
      jointConfidences: result.plan.joints.map { $0.confidence.rawValue },
      sourceFingerprint: actualFingerprint,
      sourceFingerprintMatches: true,
      importSeconds: importSeconds,
      reconstructionSeconds: reconstructionSeconds,
      beforeImport: before,
      afterImport: afterImport,
      afterReconstruction: afterReconstruction
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(report).write(to: output, options: .withoutOverwriting)
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
  }

  private static func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }

  // Identical dimension+RGBA fingerprint contract to FixtureControlGenerator.
  private static func fingerprint(_ image: RasterImage) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    func absorb(_ byte: UInt8) { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
    for value in [image.width, image.height] {
      for shift in stride(from: 0, to: 64, by: 8) {
        absorb(UInt8(truncatingIfNeeded: UInt64(value) >> UInt64(shift)))
      }
    }
    for byte in image.pixels { absorb(byte) }
    return "fnv1a64:" + String(repeating: "0", count: 16 - String(hash, radix: 16).count) + String(hash, radix: 16)
  }
}

private struct MemorySample: Codable {
  let currentResidentBytes: UInt64
  let processLifetimePeakResidentBytes: UInt64

  static func read() throws -> MemorySample {
    // Linux man-pages recommends smaps_rollup instead of approximate statm RSS.
    let lines = try String(contentsOfFile: "/proc/self/smaps_rollup", encoding: .utf8)
      .split(separator: "\n")
    guard let rssLine = lines.first(where: { $0.hasPrefix("Rss:") }),
      let rssKiB = UInt64(rssLine.split(whereSeparator: \.isWhitespace)[1])
    else { throw ProbeFailure.memoryUnavailable }
    return MemorySample(
      currentResidentBytes: rssKiB * 1_024,
      processLifetimePeakResidentBytes: try PeakMemorySampler.peakResidentBytes()
    )
  }
}

private struct ProbeReport: Codable {
  let platform: String
  let caseName: String
  let captureCount: Int
  let inputBytes: Int
  let thumbnailBytes: Int
  let resultBytes: Int
  let resultPreviewBytes: Int
  let ownedRasterBytesAfterReconstruction: Int
  let reconstructionAdmissionBytes: Int
  let ownedRasterBudgetBytes: Int
  let outputWidth: Int
  let outputHeight: Int
  let jointCount: Int
  let jointConfidences: [String]
  let sourceFingerprint: String
  let sourceFingerprintMatches: Bool
  let importSeconds: Double
  let reconstructionSeconds: Double
  let beforeImport: MemorySample
  let afterImport: MemorySample
  let afterReconstruction: MemorySample
}

private enum ProbeFailure: Error {
  case invalidArguments
  case pipeline(String)
  case timeout
  case memoryUnavailable
}
