import TraktionDomain

public struct ReconstructionEngine: Sendable {
  public let settings: ReconstructionSettings

  public init(settings: ReconstructionSettings = ReconstructionSettings()) {
    self.settings = settings
  }

  public func reconstruct(
    _ sequence: CaptureSequence,
    axis: ReconstructionAxis = .vertical
  ) throws -> ReconstructionResult {
    guard axis == .vertical else {
      throw ReconstructionFailure.unsupportedAxis(axis)
    }
    guard (2...10).contains(sequence.captures.count) else {
      throw ReconstructionFailure.captureCountOutOfRange(
        actual: sequence.captures.count,
        allowed: 2...10
      )
    }
    try validateResourceBounds(sequence.captures)
    try validateUniqueCaptures(sequence.captures)

    let expectedWidth = sequence.captures[0].image.width
    for capture in sequence.captures.dropFirst() {
      guard capture.image.width == expectedWidth else {
        throw ReconstructionFailure.incompatibleDimensions(
          expectedWidth: expectedWidth,
          actualWidth: capture.image.width,
          captureID: capture.id
        )
      }
    }

    var registrations: [PairRegistration] = []
    registrations.reserveCapacity(sequence.captures.count - 1)

    for index in 1..<sequence.captures.count {
      registrations.append(
        try register(
          preceding: sequence.captures[index - 1],
          following: sequence.captures[index]
        )
      )
    }

    let plan = try makePlan(
      captures: sequence.captures,
      registrations: registrations,
      axis: axis
    )
    let image = try render(captures: sequence.captures, plan: plan)
    return ReconstructionResult(plan: plan, image: image)
  }

  /// Reorders captures only when the supplied pixels prove one unique path of
  /// exact suffix-to-prefix overlaps. Near-exact edges are deliberately not
  /// inferred here: refusing uncertain order is safer than turning a local
  /// similarity score into documentary order.
  public func reconstructExactUnordered(
    _ captures: [CaptureAsset],
    axis: ReconstructionAxis = .vertical
  ) throws -> ReconstructionResult {
    guard axis == .vertical else {
      throw ReconstructionFailure.unsupportedAxis(axis)
    }
    guard (2...10).contains(captures.count) else {
      throw ReconstructionFailure.captureCountOutOfRange(
        actual: captures.count,
        allowed: 2...10
      )
    }
    try validateResourceBounds(captures)
    try validateUniqueCaptures(captures)

    let expectedWidth = captures[0].image.width
    for capture in captures.dropFirst() where capture.image.width != expectedWidth {
      throw ReconstructionFailure.incompatibleDimensions(
        expectedWidth: expectedWidth,
        actualWidth: capture.image.width,
        captureID: capture.id
      )
    }

    // Stable node order makes both traversal and typed ambiguity diagnostics
    // independent of the caller's arbitrary input permutation.
    let nodes = captures.sorted {
      $0.id.rawValue != $1.id.rawValue
        ? $0.id.rawValue < $1.id.rawValue
        : $0.sourceName < $1.sourceName
    }
    let tallestCapture = nodes.map(\.image.height).max() ?? 0
    guard tallestCapture <= settings.maximumOverlapSearchRows else {
      throw ReconstructionFailure.resourceLimitExceeded(
        reason: "exact sequence ordering requires up to \(tallestCapture) overlap rows; "
          + "maximum is \(settings.maximumOverlapSearchRows)"
      )
    }
    var successors = [[Int]](repeating: [], count: nodes.count)
    var orderingComparisonPixels = 0
    for preceding in nodes.indices {
      for following in nodes.indices where preceding != following {
        let overlapRows = min(nodes[preceding].image.height, nodes[following].image.height)
        let (pairPixels, pairOverflow) = expectedWidth.multipliedReportingOverflow(
          by: overlapRows
        )
        let (nextPixels, totalOverflow) = orderingComparisonPixels.addingReportingOverflow(
          pairPixels
        )
        guard !pairOverflow, !totalOverflow,
          nextPixels <= settings.maximumOrderingComparisonPixels
        else {
          throw ReconstructionFailure.resourceLimitExceeded(
            reason: "exact sequence ordering exceeds "
              + "\(settings.maximumOrderingComparisonPixels) pixel comparisons"
          )
        }
        orderingComparisonPixels = nextPixels
        if try hasExactOverlap(
          preceding: nodes[preceding].image,
          following: nodes[following].image,
          comparisonPixels: &orderingComparisonPixels
        ) {
          successors[preceding].append(following)
        }
      }
    }

    var paths: [[Int]] = []
    for start in nodes.indices {
      collectOrderingPaths(
        current: start,
        successors: successors,
        path: [start],
        visited: Set([start]),
        limit: 2,
        results: &paths
      )
      if paths.count == 2 { break }
    }

    guard let onlyPath = paths.first else {
      throw ReconstructionFailure.sequenceOrderNotFound(
        captureIDs: nodes.map(\.id)
      )
    }
    guard paths.count == 1 else {
      throw ReconstructionFailure.ambiguousSequenceOrder(
        candidateOrders: paths.map { path in path.map { nodes[$0].id } }
      )
    }

    return try reconstruct(
      CaptureSequence(captures: onlyPath.map { nodes[$0] }),
      axis: axis
    )
  }

  public func differenceImage(
    preceding: CaptureAsset,
    following: CaptureAsset,
    joint: JointDiagnosis
  ) throws -> RasterImage {
    guard preceding.image.width == following.image.width else {
      throw ReconstructionFailure.incompatibleDimensions(
        expectedWidth: preceding.image.width,
        actualWidth: following.image.width,
        captureID: following.id
      )
    }
    guard joint.overlapRows > 0,
      joint.overlapRows <= preceding.image.height,
      joint.overlapRows <= following.image.height
    else {
      throw ReconstructionFailure.invalidPlan(reason: "joint overlap is out of range")
    }

    let width = preceding.image.width
    let height = joint.overlapRows
    let byteCount = try safeByteCount(width: width, height: height)
    var output = [UInt8](repeating: 0, count: byteCount)
    let precedingStartRow = preceding.image.height - height

    for row in 0..<height {
      for column in 0..<width {
        let precedingOffset = preceding.image.byteOffset(
          x: column,
          y: precedingStartRow + row
        )
        let followingOffset = following.image.byteOffset(x: column, y: row)
        let outputOffset = ((row * width) + column) * RasterImage.channelsPerPixel

        for channel in 0..<3 {
          output[outputOffset + channel] = UInt8(
            abs(
              Int(preceding.image.pixels[precedingOffset + channel])
                - Int(following.image.pixels[followingOffset + channel])
            )
          )
        }
        output[outputOffset + 3] = 255
      }
    }

    return try RasterImage(width: width, height: height, pixels: output)
  }
}

private extension ReconstructionEngine {
  struct PairRegistration: Sendable {
    let candidate: OverlapCandidate
    let seamRowInOverlap: Int
    let confidence: JointConfidence
  }

  struct SampledCandidate: Sendable {
    let rows: Int
    let rankingError: Double
    let normalizedMeanAbsoluteErrorLowerBound: Double
    let changedPixelFractionLowerBound: Double
  }

  func hasExactOverlap(
    preceding: RasterImage,
    following: RasterImage,
    comparisonPixels: inout Int
  ) throws -> Bool {
    let maximumOverlap = min(preceding.height, following.height)
    guard maximumOverlap >= settings.minimumOverlapRows,
      maximumOverlap <= settings.maximumOverlapSearchRows
    else {
      return false
    }
    let candidates = exactOverlapCandidates(
      preceding: preceding,
      following: following,
      maximumOverlap: maximumOverlap
    )
    for overlapRows in candidates.sorted() {
      let (candidatePixels, candidateOverflow) = preceding.width.multipliedReportingOverflow(
        by: overlapRows
      )
      let (nextPixels, totalOverflow) = comparisonPixels.addingReportingOverflow(candidatePixels)
      guard !candidateOverflow, !totalOverflow,
        nextPixels <= settings.maximumOrderingComparisonPixels
      else {
        throw ReconstructionFailure.resourceLimitExceeded(
          reason: "exact sequence ordering exceeds "
            + "\(settings.maximumOrderingComparisonPixels) pixel comparisons"
        )
      }
      comparisonPixels = nextPixels
      let candidate = score(
        preceding: preceding,
        following: following,
        overlapRows: overlapRows
      )
      if candidate.normalizedMeanAbsoluteError == 0
        && candidate.changedPixelFraction == 0
      {
        return true
      }
    }
    return false
  }

  func collectOrderingPaths(
    current: Int,
    successors: [[Int]],
    path: [Int],
    visited: Set<Int>,
    limit: Int,
    results: inout [[Int]]
  ) {
    guard results.count < limit else { return }
    if path.count == successors.count {
      results.append(path)
      return
    }
    for successor in successors[current] where !visited.contains(successor) {
      collectOrderingPaths(
        current: successor,
        successors: successors,
        path: path + [successor],
        visited: visited.union([successor]),
        limit: limit,
        results: &results
      )
      if results.count == limit { return }
    }
  }

  func register(
    preceding: CaptureAsset,
    following: CaptureAsset
  ) throws -> PairRegistration {
    if preceding.image == following.image {
      throw ReconstructionFailure.duplicateCapture(
        preceding: preceding.id,
        following: following.id
      )
    }

    let maximumOverlap = min(preceding.image.height, following.image.height)
    guard maximumOverlap >= settings.minimumOverlapRows else {
      throw ReconstructionFailure.insufficientOverlap(
        preceding: preceding.id,
        following: following.id,
        minimumRows: settings.minimumOverlapRows
      )
    }
    guard maximumOverlap <= settings.maximumOverlapSearchRows else {
      throw ReconstructionFailure.resourceLimitExceeded(
        reason: "pair \(preceding.id)/\(following.id) requires \(maximumOverlap) overlap rows; maximum is \(settings.maximumOverlapSearchRows)"
      )
    }

    let exactRows = exactOverlapCandidates(
      preceding: preceding.image,
      following: following.image,
      maximumOverlap: maximumOverlap
    )

    var sampleComparisons = 0
    func chargeSampleBudget(rows: Int, columns: Int) throws {
      let (candidateComparisons, comparisonOverflow) =
        rows.multipliedReportingOverflow(by: columns)
      let (nextComparisons, totalOverflow) =
        sampleComparisons.addingReportingOverflow(candidateComparisons)
      guard !comparisonOverflow,
        !totalOverflow,
        nextComparisons <= settings.maximumSampleComparisonsPerJoint
      else {
        throw ReconstructionFailure.resourceLimitExceeded(
          reason: "sample search for pair \(preceding.id)/\(following.id) exceeds \(settings.maximumSampleComparisonsPerJoint) pixel comparisons"
        )
      }
      sampleComparisons = nextComparisons
    }
    func isPlausible(_ candidate: SampledCandidate) -> Bool {
      candidate.normalizedMeanAbsoluteErrorLowerBound
        <= settings.maximumNormalizedMeanAbsoluteError
        && candidate.changedPixelFractionLowerBound
          <= settings.maximumChangedPixelFraction
    }

    var sampled: [SampledCandidate] = []
    sampled.reserveCapacity(maximumOverlap - settings.minimumOverlapRows + 1)
    for overlapRows in settings.minimumOverlapRows...maximumOverlap {
      let rows = sampleIndices(count: overlapRows, maximum: settings.sampledRows)
      let columns = sampleIndices(count: preceding.image.width, maximum: settings.sampledColumns)
      try chargeSampleBudget(rows: rows.count, columns: columns.count)
      sampled.append(
        sampledCandidate(
          preceding: preceding.image,
          following: following.image,
          overlapRows: overlapRows,
          rowIndices: rows,
          columnIndices: columns
        )
      )
    }
    var plausible = sampled.filter(isPlausible)

    // Adaptive verification (docs/tasks/0005, ADR-013): when too many
    // candidates survive the sparse first pass, each survivor is scanned at
    // full width, rows ordered by the following capture's edge energy —
    // misalignment is provable exactly where content changes. The running
    // sums are true lower bounds at every step, so a candidate is pruned
    // the moment a bound provably exceeds a threshold; a scan that
    // completes yields the exact score. The true placement can never be
    // pruned, uniqueness and every fail-closed budget below are untouched,
    // and refinementRounds == 1 skips this pass entirely — the original
    // single-pass algorithm, byte for byte.
    if plausible.count > settings.candidateLimit && settings.refinementRounds > 1 {
      let energyOrder = rowsByDescendingEdgeEnergy(following.image)
      let width = preceding.image.width
      var refined: [SampledCandidate] = []
      refined.reserveCapacity(plausible.count)
      for candidate in plausible {
        let precedingStart = preceding.image.height - candidate.rows
        let fullPixels = candidate.rows * width
        let errorDenominator =
          Double(fullPixels) * Double(RasterImage.channelsPerPixel) * 255
        var difference: UInt64 = 0
        var changedPixels = 0
        var exceeded = false
        var lastBound = candidate

        for row in energyOrder where row < candidate.rows {
          try chargeSampleBudget(rows: 1, columns: width)
          for column in 0..<width {
            let precedingOffset = preceding.image.byteOffset(
              x: column,
              y: precedingStart + row
            )
            let followingOffset = following.image.byteOffset(x: column, y: row)
            var pixelChanged = false
            for channel in 0..<RasterImage.channelsPerPixel {
              let channelDifference = abs(
                Int(preceding.image.pixels[precedingOffset + channel])
                  - Int(following.image.pixels[followingOffset + channel])
              )
              difference += UInt64(channelDifference)
              if channelDifference > Int(settings.changedChannelThreshold) {
                pixelChanged = true
              }
            }
            if pixelChanged {
              changedPixels += 1
            }
          }

          let errorBound = Double(difference) / errorDenominator
          let changedBound = Double(changedPixels) / Double(fullPixels)
          lastBound = SampledCandidate(
            rows: candidate.rows,
            rankingError: errorBound,
            normalizedMeanAbsoluteErrorLowerBound: max(
              candidate.normalizedMeanAbsoluteErrorLowerBound,
              errorBound
            ),
            changedPixelFractionLowerBound: max(
              candidate.changedPixelFractionLowerBound,
              changedBound
            )
          )
          if errorBound > settings.maximumNormalizedMeanAbsoluteError
            || changedBound > settings.maximumChangedPixelFraction
          {
            exceeded = true
            break
          }
        }

        if !exceeded, isPlausible(lastBound) {
          refined.append(lastBound)
        }
      }
      plausible = refined
    }

    plausible.sort {
      let lhsExact = exactRows.contains($0.rows)
      let rhsExact = exactRows.contains($1.rows)
      if lhsExact != rhsExact {
        return lhsExact
      }
      if $0.rankingError == $1.rankingError {
        return $0.rows > $1.rows
      }
      return $0.rankingError < $1.rankingError
    }

    var candidatesToScore: [SampledCandidate] = []
    candidatesToScore.reserveCapacity(min(plausible.count, settings.candidateLimit))
    var fullComparisonPixels = 0
    for candidate in plausible.prefix(settings.candidateLimit) {
      let (candidatePixels, candidateOverflow) =
        preceding.image.width.multipliedReportingOverflow(by: candidate.rows)
      let (nextPixels, totalOverflow) =
        fullComparisonPixels.addingReportingOverflow(candidatePixels)
      guard !candidateOverflow,
        !totalOverflow,
        nextPixels <= settings.maximumFullComparisonPixelsPerJoint
      else {
        break
      }
      candidatesToScore.append(candidate)
      fullComparisonPixels = nextPixels
    }

    guard candidatesToScore.count == plausible.count else {
      throw ReconstructionFailure.resourceLimitExceeded(
        reason: "full verification for pair \(preceding.id)/\(following.id) exceeds its candidate or pixel-comparison budget"
      )
    }

    var scored = candidatesToScore.map {
      score(
        preceding: preceding.image,
        following: following.image,
        overlapRows: $0.rows
      )
    }
    scored.sort(by: candidateOrdering)

    let acceptable = scored.filter(isAcceptable)
    guard let best = acceptable.first else {
      throw ReconstructionFailure.insufficientOverlap(
        preceding: preceding.id,
        following: following.id,
        minimumRows: settings.minimumOverlapRows
      )
    }

    // Every acceptable overlap length represents a different translation. A lower
    // error alone cannot prove which translation is correct: a short exact repeated
    // band can otherwise outrank the true, longer near-exact overlap and duplicate
    // documentary rows. Milestone 1 therefore requires a unique acceptable offset.
    if acceptable.count > 1 {
      throw ReconstructionFailure.ambiguousOverlap(
        preceding: preceding.id,
        following: following.id,
        candidateRows: acceptable.map(\.overlapRows).sorted()
      )
    }

    let confidence: JointConfidence =
      best.normalizedMeanAbsoluteError == 0 && best.changedPixelFraction == 0
      ? .exact
      : .strong
    let seam = chooseSeam(
      preceding: preceding.image,
      following: following.image,
      overlapRows: best.overlapRows,
      exact: confidence == .exact
    )
    return PairRegistration(
      candidate: best,
      seamRowInOverlap: seam,
      confidence: confidence
    )
  }

  func makePlan(
    captures: [CaptureAsset],
    registrations: [PairRegistration],
    axis: ReconstructionAxis
  ) throws -> ReconstructionPlan {
    var origins = [0]
    origins.reserveCapacity(captures.count)

    for index in registrations.indices {
      let previousOrigin = origins[index]
      let contribution = captures[index].image.height
        - registrations[index].candidate.overlapRows
      let (nextOrigin, overflow) = previousOrigin.addingReportingOverflow(contribution)
      guard !overflow, contribution >= 0 else {
        throw ReconstructionFailure.outputDimensionsOverflow
      }
      origins.append(nextOrigin)
    }

    let (outputHeight, outputOverflow) = origins.last!.addingReportingOverflow(
      captures.last!.image.height
    )
    guard !outputOverflow else {
      throw ReconstructionFailure.outputDimensionsOverflow
    }
    _ = try safeByteCount(width: captures[0].image.width, height: outputHeight)

    let placements = captures.indices.map {
      CapturePlacement(
        captureID: captures[$0].id,
        originY: origins[$0],
        width: captures[$0].image.width,
        height: captures[$0].image.height
      )
    }
    let joints = registrations.indices.map { index in
      let registration = registrations[index]
      return JointDiagnosis(
        precedingCaptureID: captures[index].id,
        followingCaptureID: captures[index + 1].id,
        overlapRows: registration.candidate.overlapRows,
        seamRowInOverlap: registration.seamRowInOverlap,
        outputSeamRow: origins[index + 1] + registration.seamRowInOverlap,
        normalizedMeanAbsoluteError: registration.candidate.normalizedMeanAbsoluteError,
        changedPixelFraction: registration.candidate.changedPixelFraction,
        confidence: registration.confidence
      )
    }

    return ReconstructionPlan(
      axis: axis,
      outputWidth: captures[0].image.width,
      outputHeight: outputHeight,
      placements: placements,
      joints: joints
    )
  }

  func render(
    captures: [CaptureAsset],
    plan: ReconstructionPlan
  ) throws -> RasterImage {
    let byteCount = try safeByteCount(
      width: plan.outputWidth,
      height: plan.outputHeight
    )
    var output = [UInt8](repeating: 0, count: byteCount)
    let rowBytes = plan.outputWidth * RasterImage.channelsPerPixel

    for index in captures.indices {
      let placement = plan.placements[index]
      let startOutputRow = index == 0 ? 0 : plan.joints[index - 1].outputSeamRow
      let endOutputRow = index == captures.count - 1
        ? plan.outputHeight
        : plan.joints[index].outputSeamRow
      let startSourceRow = startOutputRow - placement.originY
      let endSourceRow = endOutputRow - placement.originY

      guard startSourceRow >= 0,
        endSourceRow <= captures[index].image.height,
        startSourceRow <= endSourceRow
      else {
        throw ReconstructionFailure.invalidPlan(
          reason: "capture \(captures[index].id) has an invalid source segment"
        )
      }

      for sourceRow in startSourceRow..<endSourceRow {
        let outputRow = placement.originY + sourceRow
        let sourceStart = sourceRow * rowBytes
        let outputStart = outputRow * rowBytes
        output.replaceSubrange(
          outputStart..<(outputStart + rowBytes),
          with: captures[index].image.pixels[sourceStart..<(sourceStart + rowBytes)]
        )
      }
    }

    return try RasterImage(
      width: plan.outputWidth,
      height: plan.outputHeight,
      pixels: output
    )
  }

  func exactOverlapCandidates(
    preceding: RasterImage,
    following: RasterImage,
    maximumOverlap: Int
  ) -> Set<Int> {
    let precedingHashes = rowHashes(preceding)
    let followingHashes = rowHashes(following)
    guard let firstFollowingHash = followingHashes.first else {
      return []
    }

    var matches = Set<Int>()
    for precedingStart in precedingHashes.indices
      where precedingHashes[precedingStart] == firstFollowingHash
    {
      let overlapRows = preceding.height - precedingStart
      guard overlapRows >= settings.minimumOverlapRows,
        overlapRows <= maximumOverlap,
        overlapRows <= following.height
      else {
        continue
      }

      var isMatch = true
      for row in 0..<overlapRows
        where precedingHashes[precedingStart + row] != followingHashes[row]
      {
        isMatch = false
        break
      }
      if isMatch {
        matches.insert(overlapRows)
      }
    }
    return matches
  }

  func rowHashes(_ image: RasterImage) -> [UInt64] {
    let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    let prime: UInt64 = 1_099_511_628_211
    var hashes: [UInt64] = []
    hashes.reserveCapacity(image.height)

    for row in 0..<image.height {
      var hash = offsetBasis
      let start = row * image.rowByteCount
      let end = start + image.rowByteCount
      for byte in image.pixels[start..<end] {
        hash ^= UInt64(byte)
        hash = hash &* prime
      }
      hashes.append(hash)
    }
    return hashes
  }

  func sampledCandidate(
    preceding: RasterImage,
    following: RasterImage,
    overlapRows: Int,
    rowIndices: [Int],
    columnIndices: [Int]
  ) -> SampledCandidate {
    let rows = rowIndices
    let columns = columnIndices
    let precedingStartRow = preceding.height - overlapRows
    var difference: UInt64 = 0
    var changedPixels = 0

    for row in rows {
      for column in columns {
        let precedingOffset = preceding.byteOffset(
          x: column,
          y: precedingStartRow + row
        )
        let followingOffset = following.byteOffset(x: column, y: row)
        var pixelChanged = false
        for channel in 0..<RasterImage.channelsPerPixel {
          let channelDifference = abs(
            Int(preceding.pixels[precedingOffset + channel])
              - Int(following.pixels[followingOffset + channel])
          )
          difference += UInt64(channelDifference)
          if channelDifference > Int(settings.changedChannelThreshold) {
            pixelChanged = true
          }
        }
        if pixelChanged {
          changedPixels += 1
        }
      }
    }

    let rankingDenominator = Double(rows.count)
      * Double(columns.count)
      * Double(RasterImage.channelsPerPixel)
      * 255
    let fullPixelCount = overlapRows * preceding.width
    let fullErrorDenominator = Double(fullPixelCount)
      * Double(RasterImage.channelsPerPixel)
      * 255
    return SampledCandidate(
      rows: overlapRows,
      rankingError: Double(difference) / rankingDenominator,
      normalizedMeanAbsoluteErrorLowerBound: Double(difference)
        / fullErrorDenominator,
      changedPixelFractionLowerBound: Double(changedPixels)
        / Double(fullPixelCount)
    )
  }

  func score(
    preceding: RasterImage,
    following: RasterImage,
    overlapRows: Int
  ) -> OverlapCandidate {
    let precedingStartRow = preceding.height - overlapRows
    var absoluteDifference: UInt64 = 0
    var changedPixels = 0

    for row in 0..<overlapRows {
      for column in 0..<preceding.width {
        let precedingOffset = preceding.byteOffset(
          x: column,
          y: precedingStartRow + row
        )
        let followingOffset = following.byteOffset(x: column, y: row)
        var pixelChanged = false

        for channel in 0..<RasterImage.channelsPerPixel {
          let difference = abs(
            Int(preceding.pixels[precedingOffset + channel])
              - Int(following.pixels[followingOffset + channel])
          )
          absoluteDifference += UInt64(difference)
          if difference > Int(settings.changedChannelThreshold) {
            pixelChanged = true
          }
        }
        if pixelChanged {
          changedPixels += 1
        }
      }
    }

    let comparedPixels = overlapRows * preceding.width
    let denominator = Double(comparedPixels)
      * Double(RasterImage.channelsPerPixel)
      * 255
    return OverlapCandidate(
      overlapRows: overlapRows,
      normalizedMeanAbsoluteError: Double(absoluteDifference) / denominator,
      changedPixelFraction: Double(changedPixels) / Double(comparedPixels)
    )
  }

  func candidateOrdering(
    _ lhs: OverlapCandidate,
    _ rhs: OverlapCandidate
  ) -> Bool {
    if lhs.normalizedMeanAbsoluteError != rhs.normalizedMeanAbsoluteError {
      return lhs.normalizedMeanAbsoluteError < rhs.normalizedMeanAbsoluteError
    }
    if lhs.changedPixelFraction != rhs.changedPixelFraction {
      return lhs.changedPixelFraction < rhs.changedPixelFraction
    }
    return lhs.overlapRows > rhs.overlapRows
  }

  func isAcceptable(_ candidate: OverlapCandidate) -> Bool {
    candidate.normalizedMeanAbsoluteError
      <= settings.maximumNormalizedMeanAbsoluteError
      && candidate.changedPixelFraction <= settings.maximumChangedPixelFraction
  }

  func chooseSeam(
    preceding: RasterImage,
    following: RasterImage,
    overlapRows: Int,
    exact: Bool
  ) -> Int {
    guard overlapRows > 2 else {
      return max(1, overlapRows / 2)
    }
    let center = overlapRows / 2
    if exact {
      return center
    }

    let inset = max(1, overlapRows / 8)
    let lowerBound = inset
    let upperBound = max(lowerBound, overlapRows - inset - 1)
    let precedingStartRow = preceding.height - overlapRows
    var bestRow = center
    var bestCost = UInt64.max

    for row in lowerBound...upperBound {
      var rowCost: UInt64 = 0
      for column in 0..<preceding.width {
        let precedingOffset = preceding.byteOffset(
          x: column,
          y: precedingStartRow + row
        )
        let followingOffset = following.byteOffset(x: column, y: row)
        for channel in 0..<RasterImage.channelsPerPixel {
          rowCost += UInt64(
            abs(
              Int(preceding.pixels[precedingOffset + channel])
                - Int(following.pixels[followingOffset + channel])
            )
          )
        }
      }

      let rowDistance = abs(row - center)
      let bestDistance = abs(bestRow - center)
      if rowCost < bestCost
        || (rowCost == bestCost && rowDistance < bestDistance)
        || (rowCost == bestCost && rowDistance == bestDistance && row < bestRow)
      {
        bestCost = rowCost
        bestRow = row
      }
    }
    return bestRow
  }

  func sampleIndices(count: Int, maximum: Int) -> [Int] {
    guard count > maximum else {
      return Array(0..<count)
    }
    return (0..<maximum).map { sample in
      sample * (count - 1) / (maximum - 1)
    }
  }

  /// Row indices of `image` ordered by descending adjacent-row difference
  /// (edge-energy proxy; RECONSTRUCTION_SPEC.md §2), ties broken by ascending
  /// index. Refinement samples these rows first because misalignment is
  /// provable exactly where content changes.
  func rowsByDescendingEdgeEnergy(_ image: RasterImage) -> [Int] {
    var energies = [Int](repeating: 0, count: image.height)
    for row in 1..<image.height {
      let currentStart = row * image.rowByteCount
      let previousStart = currentStart - image.rowByteCount
      var difference = 0
      for offset in 0..<image.rowByteCount {
        difference += abs(
          Int(image.pixels[currentStart + offset]) - Int(image.pixels[previousStart + offset])
        )
      }
      energies[row] = difference
    }
    return (0..<image.height).sorted {
      energies[$0] != energies[$1] ? energies[$0] > energies[$1] : $0 < $1
    }
  }

  func validateResourceBounds(_ captures: [CaptureAsset]) throws {
    var totalPixels = 0
    for capture in captures {
      let (pixels, pixelOverflow) = capture.image.width.multipliedReportingOverflow(
        by: capture.image.height
      )
      guard !pixelOverflow, pixels <= settings.maximumCapturePixels else {
        throw ReconstructionFailure.resourceLimitExceeded(
          reason: "capture \(capture.id) exceeds \(settings.maximumCapturePixels) pixels"
        )
      }
      let (nextTotal, totalOverflow) = totalPixels.addingReportingOverflow(pixels)
      guard !totalOverflow, nextTotal <= settings.maximumTotalInputPixels else {
        throw ReconstructionFailure.resourceLimitExceeded(
          reason: "input sequence exceeds \(settings.maximumTotalInputPixels) pixels"
        )
      }
      totalPixels = nextTotal
    }
  }

  func validateUniqueCaptures(_ captures: [CaptureAsset]) throws {
    for followingIndex in captures.indices.dropFirst() {
      for precedingIndex in captures.indices.prefix(upTo: followingIndex)
        where captures[precedingIndex].image == captures[followingIndex].image
      {
        throw ReconstructionFailure.duplicateCapture(
          preceding: captures[precedingIndex].id,
          following: captures[followingIndex].id
        )
      }
    }
  }

  func safeByteCount(width: Int, height: Int) throws -> Int {
    let (pixels, pixelOverflow) = width.multipliedReportingOverflow(by: height)
    let (bytes, byteOverflow) = pixels.multipliedReportingOverflow(
      by: RasterImage.channelsPerPixel
    )
    guard width > 0, height > 0, !pixelOverflow, !byteOverflow else {
      throw ReconstructionFailure.outputDimensionsOverflow
    }
    guard pixels <= settings.maximumOutputPixels else {
      throw ReconstructionFailure.resourceLimitExceeded(
        reason: "output exceeds \(settings.maximumOutputPixels) pixels"
      )
    }
    return bytes
  }
}
