import FixtureForgeKit
import Foundation
import TraktionDomain
import TraktionLabEvaluation
@testable import TraktionUI

// Separate fixture generation from this fresh-process, synchronous worker probe.
// Linux measures raster arrays and runtime RSS, not SwiftUI, CGImage, GPU, or device memory.
@main
struct ProbeInspection {
  static func main() throws {
    guard CommandLine.arguments.count == 3 else { throw ProbeError.arguments }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1])
    let truth = try JSONDecoder().decode(FixtureGroundTruth.self,
      from: Data(contentsOf: directory.appendingPathComponent("fixture.json")))
    let worker = NativeWorkspaceWorker()
    let captures = try worker.importCaptures(
      from: truth.captures.map { directory.appendingPathComponent($0.fileName) },
      retainedRasterBytes: 0, isCancelled: { false })
    let thumbnails = try captures.map {
      try NativeRasterPreview.make($0.image, maximumDimension: 224, maximumPixels: 224 * 224, isCancelled: { false })
    }
    let result = try worker.reconstruct(captures)
    let preview = try NativeRasterPreview.make(result.image,
      maximumDimension: 4_096, maximumPixels: 1_048_576, isCancelled: { false })
    let retained = captures.reduce(0) { $0 + $1.image.pixels.count }
      + thumbnails.reduce(0) { $0 + $1.pixels.count * 2 }
      + result.image.pixels.count + preview.pixels.count * 2
    guard retained + InspectionViewport.reservedBytes <= 268_435_456 else { throw ProbeError.budget }
    let peakBefore = try PeakMemorySampler.peakResidentBytes()
    let rssBefore = try currentRSS()
    var previous: InspectionFrame?
    var timings: [Double] = []
    var maximumFrameBytes = 0
    let viewports = try [0, result.image.height / 2, result.image.height - 720].map {
      try InspectionViewport(width: 960, height: 720, x: 100, y: Double($0), zoom: 1)
    } + [InspectionViewport(width: 960, height: 720, x: 0, y: 0, zoom: 720.0 / Double(result.image.height))]
    let renderer = InspectionRasterRenderer()
    for viewport in viewports {
      let start = ContinuousClock.now
      let frame = try renderer.render(result.image, viewport: viewport, isCancelled: { false })
      let elapsed = start.duration(to: .now).components
      timings.append(Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
      maximumFrameBytes = max(maximumFrameBytes, frame.raster.pixels.count)
      // Keep a prior and new frame live across sampling, as allowed by admission.
      try withExtendedLifetime(previous) {
        guard frame.raster.pixels.count <= InspectionViewport.maximumBytes else { throw ProbeError.budget }
      }
      previous = frame
    }
    let (peakAfter, rssAfter) = try withExtendedLifetime((captures, thumbnails, result, preview, previous)) {
      (try PeakMemorySampler.peakResidentBytes(), try currentRSS())
    }
    let report = Report(
      scope: "Linux Swift 6.0.3 release; synchronous production import/reconstruction/inspection raster renderer; no SwiftUI/CGImage/model scheduler/GPU/device claim",
      captures: captures.count, width: result.image.width, height: result.image.height,
      workspaceRetainedBytesWithPreviewCopies: retained,
      inspectionReservedBytes: InspectionViewport.reservedBytes,
      admittedTotalBytes: retained + InspectionViewport.reservedBytes,
      maximumActualFrameBytes: maximumFrameBytes, frameSeconds: timings,
      peakResidentBeforeInspection: peakBefore, peakResidentAfterInspection: peakAfter,
      currentResidentBeforeInspection: rssBefore, currentResidentAfterInspection: rssAfter)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .withoutOverwriting)
    print(String(decoding: data, as: UTF8.self))
  }

  static func currentRSS() throws -> UInt64 {
    let lines = try String(contentsOfFile: "/proc/self/smaps_rollup", encoding: .utf8).split(separator: "\n")
    guard let line = lines.first(where: { $0.hasPrefix("Rss:") }),
      let kib = UInt64(line.split(whereSeparator: \.isWhitespace)[1]) else { throw ProbeError.memory }
    return kib * 1_024
  }
}

private enum ProbeError: Error { case arguments, budget, memory }
private struct Report: Codable {
  let scope: String
  let captures: Int
  let width: Int
  let height: Int
  let workspaceRetainedBytesWithPreviewCopies: Int
  let inspectionReservedBytes: Int
  let admittedTotalBytes: Int
  let maximumActualFrameBytes: Int
  let frameSeconds: [Double]
  let peakResidentBeforeInspection: UInt64
  let peakResidentAfterInspection: UInt64
  let currentResidentBeforeInspection: UInt64
  let currentResidentAfterInspection: UInt64
}
