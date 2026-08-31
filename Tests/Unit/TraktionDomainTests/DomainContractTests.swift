import Foundation
import Testing
import TraktionDomain

@Suite("Domain contracts")
struct DomainContractTests {
    @Test("ReconstructionFailure round-trips through Codable for every case")
    func failureCodableRoundTrip() throws {
        let cases: [ReconstructionFailure] = [
            .insufficientOverlap(jointIndex: 2),
            .missingCoverage(jointIndex: 0),
            .incompatibleDimensions(assetID: "capture-002", expectedWidth: 96, foundWidth: 128),
            .dynamicConflict(jointIndex: 1),
            .ambiguousOrder,
            .unsupportedTransform(details: "horizontal"),
            .invalidCaptureCount(found: 1, minimum: 2, maximum: 10),
            .unreadableAsset(fileName: "x.png", reason: "not a PNG"),
        ]
        for failure in cases {
            let data = try DeterministicJSON.encode(failure)
            let decoded = try DeterministicJSON.decode(ReconstructionFailure.self, from: data)
            #expect(decoded == failure)
        }
    }

    @Test("Axis and confidence raw values are stable wire contracts")
    func rawValues() {
        #expect(ReconstructionAxis.vertical.rawValue == "vertical")
        #expect(ReconstructionAxis.horizontal.rawValue == "horizontal")
        #expect(JointConfidence.allCases.map(\.rawValue) == ["exact", "strong", "review", "gap", "conflict"])
    }

    @Test("Manifest encoding is deterministic and round-trips")
    func manifestDeterminism() throws {
        let manifest = ReconstructionManifest(
            generator: "test 0.0.0",
            axis: .vertical,
            status: .failed,
            captures: [
                CaptureAsset(id: "capture-001", fileName: "a.png", pixelWidth: 96, pixelHeight: 64, byteCount: 123, sha256: "00ff"),
            ],
            failure: .invalidCaptureCount(found: 1, minimum: 2, maximum: 10)
        )
        let first = try DeterministicJSON.encode(manifest)
        let second = try DeterministicJSON.encode(manifest)
        #expect(first == second)
        let decoded = try DeterministicJSON.decode(ReconstructionManifest.self, from: first)
        #expect(decoded == manifest)
    }
}
