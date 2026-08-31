import FixtureForgeKit
import TraktionCore
import XCTest

final class ReconstructionPerformanceTests: XCTestCase {
  func testLargeSyntheticFixtureUsesOneFinalOutputBufferShape() throws {
    let fixture = try SyntheticFixtureFactory.large()
    let clock = ContinuousClock()
    let start = clock.now
    let result = try ReconstructionEngine().reconstruct(fixture.sequence)
    let elapsed = start.duration(to: clock.now)

    XCTAssertEqual(result.image, fixture.source)
    XCTAssertEqual(
      result.image.pixels.count,
      fixture.source.width * fixture.source.height * 4
    )
    print("TRAKTION_PERF large fixture: \(elapsed)")
  }
}
