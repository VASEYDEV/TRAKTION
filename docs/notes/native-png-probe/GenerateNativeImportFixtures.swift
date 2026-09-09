import FixtureForgeKit
import Foundation
import TraktionVision

// Run in a separate process from the measured worker. The long documentary
// source exceeds the codec's per-PNG limit, so persist captures and truth only.
@main
struct GenerateNativeImportFixtures {
  static func main() throws {
    guard CommandLine.arguments.count == 3,
      let count = Int(CommandLine.arguments[1]), [3, 10].contains(count)
    else { throw ProbeInput.invalidArguments }
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    guard !FileManager.default.fileExists(atPath: output.path) else {
      throw ProbeInput.existingDestination
    }
    let name = count == 3 ? "performance-phone-3" : "performance-long-10"
    let bundle = try FixtureControlGenerator.generate(FixtureControlConfiguration(
      sourceID: name, crossAxisSize: 1170, viewportLength: 2532,
      captureCount: count, overlapLength: 700, seed: 51
    ))
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    for capture in bundle.captures {
      try PNGCodec.encodeOpaqueRGBA8(
        capture.image, to: output.appendingPathComponent(capture.sourceName)
      )
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(bundle.groundTruth).write(
      to: output.appendingPathComponent("fixture.json"), options: .withoutOverwriting
    )
    print("Generated \(count) captures at 1170x2532; source 1170x\(bundle.source.height); overlap 700; seed 51.")
    print("Source fingerprint: \(bundle.groundTruth.sourcePixelFingerprint)")
  }
}

private enum ProbeInput: Error {
  case invalidArguments
  case existingDestination
}
