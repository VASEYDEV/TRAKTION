import Foundation
import TraktionDomain
import TraktionLabKit

// traktion-lab — diagnostic CLI over the shipping reconstruction core.
// Bootstrap stage implements `ingest` only; `reconstruct` lands with
// prompts/01_PHASE1_CORE_LAB.md and must fail explicitly until then.

let usage = """
usage: traktion-lab ingest [--axis vertical|horizontal] --output <base-path> <capture.png> ...

Loads captures in the supplied order, validates Milestone 1 constraints, and
writes <base-path>.reconstruction.json. Exits non-zero on failure; a failed
run still writes a manifest with the typed failure.
"""

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail(usage, code: 64)
}
arguments.removeFirst()

switch command {
case "ingest":
    var axis = ReconstructionAxis.vertical
    var outputBase: String?
    var inputs: [String] = []
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--axis":
            guard index + 1 < arguments.count else { fail("--axis requires a value\n\(usage)", code: 64) }
            guard let parsed = ReconstructionAxis(rawValue: arguments[index + 1]) else {
                fail("unknown axis '\(arguments[index + 1])'; expected vertical or horizontal", code: 64)
            }
            axis = parsed
            index += 2
        case "--output":
            guard index + 1 < arguments.count else { fail("--output requires a value\n\(usage)", code: 64) }
            outputBase = arguments[index + 1]
            index += 2
        default:
            guard !argument.hasPrefix("--") else { fail("unknown option '\(argument)'\n\(usage)", code: 64) }
            inputs.append(argument)
            index += 1
        }
    }
    guard let outputBase else { fail("--output is required\n\(usage)", code: 64) }
    guard !inputs.isEmpty else { fail("at least one capture file is required\n\(usage)", code: 64) }

    do {
        let outcome = try LabIngest.run(inputPaths: inputs, axis: axis, outputBase: outputBase)
        print("manifest: \(outcome.manifestPath)")
        switch outcome.manifest.status {
        case .ingested:
            print("status: ingested (\(outcome.manifest.captures.count) captures)")
        case .failed:
            let reason = outcome.manifest.failure.map(String.init(describing:)) ?? "unknown failure"
            print("status: failed — \(reason)")
            exit(1)
        }
    } catch {
        fail("ingest could not write diagnostics: \(error)", code: 74)
    }
case "reconstruct":
    fail("reconstruct is not implemented yet (tracked by prompts/01_PHASE1_CORE_LAB.md); ingest is available", code: 64)
default:
    fail("unknown command '\(command)'\n\(usage)", code: 64)
}
