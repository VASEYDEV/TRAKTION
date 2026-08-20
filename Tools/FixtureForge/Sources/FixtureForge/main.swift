import Foundation
import TraktionVision

@main enum FixtureForge {
  static func main() {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      guard arguments.count == 1 else { throw ForgeError.usage }
      let directory = URL(fileURLWithPath: arguments[0], isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let source = deterministicCanvas(width: 32, height: 48)
      try PNGCodec.encode(source, to: directory.appendingPathComponent("source.png"))
      try PNGCodec.encode(
        crop(source, 0..<32), to: directory.appendingPathComponent("capture-001.png"))
      try PNGCodec.encode(
        crop(source, 16..<48), to: directory.appendingPathComponent("capture-002.png"))
      print("Wrote deterministic two-capture fixture to \(directory.path).")
    } catch {
      FileHandle.standardError.write(Data("fixture-forge: \(error.localizedDescription)\n".utf8))
      exit(1)
    }
  }

  static func deterministicCanvas(width: Int, height: Int) -> PixelImage {
    var pixels = [UInt8]()
    pixels.reserveCapacity(width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        pixels += [
          UInt8((x * 17 + y * 11) % 251), UInt8((x * 7 + y * 29) % 253),
          UInt8((x * 31 + y * 3) % 255), 255,
        ]
      }
    }
    return PixelImage(width: width, height: height, rgba: pixels)
  }
  static func crop(_ image: PixelImage, _ rows: Range<Int>) -> PixelImage {
    PixelImage(width: image.width, height: rows.count, rgba: Array(image.rows(rows)))
  }
}
private enum ForgeError: LocalizedError {
  case usage
  var errorDescription: String? { "usage: fixture-forge OUTPUT_DIRECTORY" }
}
