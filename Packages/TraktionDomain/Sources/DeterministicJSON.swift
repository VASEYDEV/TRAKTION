import Foundation

/// Shared JSON encoding for machine-readable artifacts (manifests, ground
/// truth). Sorted keys and stable formatting keep identical values
/// byte-identical run to run, which golden comparisons rely on.
public enum DeterministicJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        var data = try encoder.encode(value)
        data.append(0x0a) // trailing newline for POSIX-friendly text files
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
