import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

@main enum TraktionLab {
  static func main() {
    do { try run(Array(CommandLine.arguments.dropFirst())) } catch {
      FileHandle.standardError.write(Data("traktion-lab: \(error.localizedDescription)\n".utf8))
      exit(1)
    }
  }

  static func run(_ arguments: [String]) throws {
    guard arguments.first == "reconstruct" else { throw CLIError.usage }
    var outputURL: URL?
    var inputs = [URL]()
    var index = 1
    while index < arguments.count {
      switch arguments[index] {
      case "--axis":
        guard index + 1 < arguments.count, arguments[index + 1] == "vertical" else {
          throw CLIError.onlyVertical
        }
        index += 2
      case "--output":
        guard index + 1 < arguments.count else { throw CLIError.usage }
        outputURL = URL(fileURLWithPath: arguments[index + 1])
        index += 2
      default:
        inputs.append(URL(fileURLWithPath: arguments[index]))
        index += 1
      }
    }
    guard let outputURL else { throw CLIError.usage }
    let loaded = try inputs.enumerated().map { position, url in
      let image = try PNGCodec.decode(contentsOf: url)
      return (
        CaptureAsset(
          id: String(format: "capture-%03d", position + 1), source: url, width: image.width,
          height: image.height), image
      )
    }
    let result = try Reconstructor().reconstruct(images: loaded)
    let fileManager = FileManager.default
    let directory = outputURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try PNGCodec.encode(result.image, to: outputURL)
    let stem = outputURL.deletingPathExtension().lastPathComponent
    let manifestURL = directory.appendingPathComponent("\(stem).reconstruction.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(result.plan).write(to: manifestURL, options: .atomic)
    for (jointIndex, joint) in result.plan.joints.enumerated() {
      let payload = JointDiagnostic(joint: joint, candidates: result.candidates[jointIndex])
      let url = directory.appendingPathComponent(
        String(format: "%@.joint-%03d.json", stem, jointIndex + 1))
      try encoder.encode(payload).write(to: url, options: .atomic)
    }
    print(
      "Reconstructed \(inputs.count) captures to \(outputURL.path) (\(result.plan.outputWidth)×\(result.plan.outputHeight))."
    )
  }
}

private struct JointDiagnostic: Codable {
  let joint: JointDiagnosis
  let candidates: [OverlapCandidate]
}
private enum CLIError: LocalizedError {
  case usage, onlyVertical
  var errorDescription: String? {
    switch self {
    case .usage:
      "usage: traktion-lab reconstruct --axis vertical --output composite.png capture-001.png capture-002.png [...]"
    case .onlyVertical: "Milestone 1 supports only --axis vertical."
    }
  }
}
