import Foundation
import FixtureForgeKit

// fixtureforge — deterministic fixture generator. Same seed and configuration
// always produce byte-identical output.

let usage = """
usage: fixtureforge generate --output <directory> [--source-id <name>] [--width N] \
[--viewport N] [--captures N] [--overlap N] [--seed N]

Writes source.png, capture-XXX.png files, and fixture.json (ground truth)
into the output directory. Defaults: width 96, viewport 64, captures 3,
overlap 16, seed 1.
"""

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func parseInt(_ value: String, for option: String) -> Int {
    guard let parsed = Int(value) else { fail("\(option) expects an integer, got '\(value)'", code: 64) }
    return parsed
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.first == "generate" else {
    fail(usage, code: 64)
}
arguments.removeFirst()

var config = FixtureConfiguration()
var outputDirectory: String?
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    guard index + 1 < arguments.count else { fail("\(argument) requires a value\n\(usage)", code: 64) }
    let value = arguments[index + 1]
    switch argument {
    case "--output": outputDirectory = value
    case "--source-id": config.sourceID = value
    case "--width": config.width = parseInt(value, for: argument)
    case "--viewport": config.viewportHeight = parseInt(value, for: argument)
    case "--captures": config.captureCount = parseInt(value, for: argument)
    case "--overlap": config.overlap = parseInt(value, for: argument)
    case "--seed":
        guard let seed = UInt64(value) else { fail("--seed expects an unsigned integer", code: 64) }
        config.seed = seed
    default:
        fail("unknown option '\(argument)'\n\(usage)", code: 64)
    }
    index += 2
}

guard let outputDirectory else { fail("--output is required\n\(usage)", code: 64) }

do {
    let fixture = try FixtureGenerator.generate(config)
    let manifestURL = try FixtureGenerator.write(fixture, to: URL(fileURLWithPath: outputDirectory))
    print("fixture: \(manifestURL.path)")
    print("source: \(fixture.manifest.sourceWidth)x\(fixture.manifest.sourceHeight), \(fixture.manifest.captures.count) captures, overlap \(config.overlap)")
} catch let error as FixtureGeneratorError {
    fail("fixture generation failed: \(error)", code: 65)
} catch {
    fail("fixture generation failed: \(error)", code: 74)
}
