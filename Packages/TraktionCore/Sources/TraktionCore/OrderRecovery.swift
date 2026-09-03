import TraktionDomain

/// Automatic order recovery (Milestone 2, docs/adr/ADR-015).
///
/// The documentary order of an unordered capture set is recovered from the
/// pairwise overlap graph: a directed edge i → j exists exactly when the
/// Milestone 1 registration pipeline accepts a unique overlap in which j
/// continues i. The recovered order must be the single directed path that
/// covers every capture; anything else is a typed refusal — more than one
/// acceptable order is `ambiguousOrder`, none is `missingCoverage`. A
/// pair-level `ambiguousOverlap` contributes no edge, and any budget
/// exhaustion while probing fails the whole recovery, so no order is ever
/// chosen from a partial or unprovable graph.
extension ReconstructionEngine {
  public func recoverOrder(_ captures: [CaptureAsset]) throws -> RecoveredOrder {
    try solveOrder(captures).recovery
  }

  /// Recovers the order, then reconstructs through the supplied-order path,
  /// so the final plan and pixels are always produced — and every junction
  /// re-verified — by the reviewed Milestone 1 pipeline.
  public func reconstructRecoveringOrder(
    _ captures: [CaptureAsset],
    axis: ReconstructionAxis = .vertical
  ) throws -> OrderedReconstruction {
    guard axis == .vertical else {
      throw ReconstructionFailure.unsupportedAxis(axis)
    }
    let solved = try solveOrder(captures)
    let ordered = solved.orderedIndices.map { captures[$0] }
    let result = try reconstruct(CaptureSequence(captures: ordered), axis: axis)
    return OrderedReconstruction(order: solved.recovery, result: result)
  }
}

extension ReconstructionEngine {
  /// Bound on the candidate orders embedded in an `ambiguousOrder` payload;
  /// the failure also carries the exact total.
  static let ambiguousOrderSampleLimit = 4

  func solveOrder(
    _ captures: [CaptureAsset]
  ) throws -> (orderedIndices: [Int], recovery: RecoveredOrder) {
    guard (2...10).contains(captures.count) else {
      throw ReconstructionFailure.captureCountOutOfRange(
        actual: captures.count,
        allowed: 2...10
      )
    }
    try validateResourceBounds(captures)
    try validateUniqueCaptures(captures)
    let expectedWidth = captures[0].image.width
    for capture in captures.dropFirst() {
      guard capture.image.width == expectedWidth else {
        throw ReconstructionFailure.incompatibleDimensions(
          expectedWidth: expectedWidth,
          actualWidth: capture.image.width,
          captureID: capture.id
        )
      }
    }

    var edges = [[PairRegistration?]](
      repeating: [PairRegistration?](repeating: nil, count: captures.count),
      count: captures.count
    )
    for precedingIndex in captures.indices {
      for followingIndex in captures.indices
        where followingIndex != precedingIndex
      {
        switch try probePair(
          preceding: captures[precedingIndex],
          following: captures[followingIndex]
        ) {
        case .accepted(let registration):
          edges[precedingIndex][followingIndex] = registration
        case .insufficientOverlap, .ambiguousOverlap:
          break
        }
      }
    }

    let hasEdge: (Int, Int) -> Bool = { edges[$0][$1] != nil }
    let totalOrders = countFullOrders(count: captures.count, hasEdge: hasEdge)
    guard totalOrders > 0 else {
      let chain = longestChain(count: captures.count, hasEdge: hasEdge)
      let covered = Set(chain)
      throw ReconstructionFailure.missingCoverage(
        coveredCaptureIDs: chain.map { captures[$0].id },
        uncoveredCaptureIDs: captures.indices
          .filter { !covered.contains($0) }
          .map { captures[$0].id }
      )
    }
    guard totalOrders == 1 else {
      let sample = enumerateFullOrders(
        count: captures.count,
        hasEdge: hasEdge,
        limit: Self.ambiguousOrderSampleLimit
      )
      throw ReconstructionFailure.ambiguousOrder(
        candidateOrders: sample.map { order in order.map { captures[$0].id } },
        totalCandidates: totalOrders
      )
    }

    let order = enumerateFullOrders(
      count: captures.count,
      hasEdge: hasEdge,
      limit: 1
    )[0]
    let recoveredEdges = zip(order, order.dropFirst()).map {
      precedingIndex, followingIndex -> RecoveredEdge in
      let registration = edges[precedingIndex][followingIndex]!
      return RecoveredEdge(
        precedingCaptureID: captures[precedingIndex].id,
        followingCaptureID: captures[followingIndex].id,
        candidate: registration.candidate,
        confidence: registration.confidence
      )
    }
    return (
      orderedIndices: order,
      recovery: RecoveredOrder(
        captureIDs: order.map { captures[$0].id },
        edges: recoveredEdges
      )
    )
  }

  /// Exact count of directed paths covering every capture. Subset dynamic
  /// programming; with at most 10 captures the count is bounded by 10!
  /// (3,628,800), far inside `Int`.
  func countFullOrders(count: Int, hasEdge: (Int, Int) -> Bool) -> Int {
    var pathCounts = [[Int]](
      repeating: [Int](repeating: 0, count: count),
      count: 1 << count
    )
    for start in 0..<count {
      pathCounts[1 << start][start] = 1
    }
    for mask in 1..<(1 << count) {
      for last in 0..<count where pathCounts[mask][last] > 0 {
        for next in 0..<count
          where mask & (1 << next) == 0 && hasEdge(last, next)
        {
          pathCounts[mask | (1 << next)][next] += pathCounts[mask][last]
        }
      }
    }
    let fullMask = (1 << count) - 1
    return (0..<count).reduce(0) { $0 + pathCounts[fullMask][$1] }
  }

  /// The first `limit` full-coverage orders in lexicographic index order —
  /// deterministic for identical inputs.
  func enumerateFullOrders(
    count: Int,
    hasEdge: (Int, Int) -> Bool,
    limit: Int
  ) -> [[Int]] {
    var results: [[Int]] = []
    var path: [Int] = []
    var used = [Bool](repeating: false, count: count)

    func descend() {
      if path.count == count {
        results.append(path)
        return
      }
      for next in 0..<count where !used[next] {
        if let last = path.last, !hasEdge(last, next) {
          continue
        }
        used[next] = true
        path.append(next)
        descend()
        path.removeLast()
        used[next] = false
        if results.count >= limit {
          return
        }
      }
    }

    descend()
    return results
  }

  /// The longest acceptable chain, preferring the lexicographically smallest
  /// index sequence among equals — a deterministic diagnostic for
  /// `missingCoverage`, never an output selection.
  func longestChain(count: Int, hasEdge: (Int, Int) -> Bool) -> [Int] {
    var best: [Int] = []
    var path: [Int] = []
    var used = [Bool](repeating: false, count: count)

    func descend() {
      if path.count > best.count {
        best = path
      }
      for next in 0..<count where !used[next] {
        if let last = path.last, !hasEdge(last, next) {
          continue
        }
        used[next] = true
        path.append(next)
        descend()
        path.removeLast()
        used[next] = false
      }
    }

    descend()
    return best
  }
}
