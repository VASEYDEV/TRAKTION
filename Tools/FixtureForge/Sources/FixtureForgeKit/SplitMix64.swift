/// Deterministic seeded PRNG (SplitMix64). Identical sequences on every
/// platform; never replace with SystemRandomNumberGenerator in fixture code.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

/// Stateless deterministic 64-bit mix of two values (same core as SplitMix64),
/// used for position-dependent pixel patterns.
@inlinable
public func deterministicMix(_ a: UInt64, _ b: UInt64) -> UInt64 {
    var z = a &+ 0x9e3779b97f4a7c15 &* (b &+ 1)
    z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
    z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
    return z ^ (z >> 31)
}
