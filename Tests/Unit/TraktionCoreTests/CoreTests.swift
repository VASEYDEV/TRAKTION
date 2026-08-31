import Testing
import TraktionCore
import TraktionDomain

@Suite("SHA-256")
struct SHA256Tests {
    @Test("Matches FIPS 180-4 reference vectors")
    func referenceVectors() {
        #expect(SHA256.hexDigest([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(SHA256.hexDigest(Array("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(SHA256.hexDigest(Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8))
            == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        let millionA = [UInt8](repeating: UInt8(ascii: "a"), count: 1_000_000)
        #expect(SHA256.hexDigest(millionA) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }
}

@Suite("Milestone 1 sequence validation")
struct SequenceValidatorTests {
    private func asset(_ id: String, width: Int = 96, height: Int = 64) -> CaptureAsset {
        CaptureAsset(id: id, fileName: "\(id).png", pixelWidth: width, pixelHeight: height, byteCount: 1, sha256: "00")
    }

    @Test("Accepts a valid vertical sequence")
    func acceptsValid() {
        let sequence = CaptureSequence(axis: .vertical, captures: [asset("a"), asset("b"), asset("c")])
        #expect(SequenceValidator.validate(sequence) == nil)
    }

    @Test("Rejects too few and too many captures with a typed failure")
    func captureCountBounds() {
        let one = CaptureSequence(axis: .vertical, captures: [asset("a")])
        #expect(SequenceValidator.validate(one) == .invalidCaptureCount(found: 1, minimum: 2, maximum: 10))

        let eleven = CaptureSequence(axis: .vertical, captures: (0..<11).map { asset("a\($0)") })
        #expect(SequenceValidator.validate(eleven) == .invalidCaptureCount(found: 11, minimum: 2, maximum: 10))
    }

    @Test("Rejects width mismatches, naming the offending asset")
    func widthMismatch() {
        let sequence = CaptureSequence(axis: .vertical, captures: [asset("a"), asset("b", width: 128)])
        #expect(SequenceValidator.validate(sequence)
            == .incompatibleDimensions(assetID: "b", expectedWidth: 96, foundWidth: 128))
    }

    @Test("Rejects horizontal reconstruction as unsupported in Milestone 1")
    func horizontalUnsupported() {
        let sequence = CaptureSequence(axis: .horizontal, captures: [asset("a"), asset("b")])
        guard case .unsupportedTransform? = SequenceValidator.validate(sequence) else {
            Issue.record("expected unsupportedTransform")
            return
        }
    }
}
