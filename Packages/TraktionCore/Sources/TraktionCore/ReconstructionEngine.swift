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

    let maximumOverlap = min(preceding.image.height, following.image.height) - 1
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

    var sampled: [(rows: Int, score: Double)] = []
    sampled.reserveCapacity(maximumOverlap - settings.minimumOverlapRows + 1)
    for overlapRows in settings.minimumOverlapRows...maximumOverlap {
      sampled.append(
        (
          rows: overlapRows,
          score: sampledError(
            preceding: preceding.image,
            following: following.image,
            overlapRows: overlapRows
          )
        )
      )
    }
    sampled.sort {
      if $0.score == $1.score {
        return $0.rows > $1.rows
      }
      return $0.score < $1.score
    }

    let plausible = sampled.filter {
      $0.score <= settings.maximumNormalizedMeanAbsoluteError
    }
    guard plausible.count <= settings.candidateLimit else {
      throw ReconstructionFailure.ambiguousOverlap(
        preceding: preceding.id,
        following: following.id,
        candidateRows: plausible.prefix(settings.candidateLimit + 1).map(\.rows).sorted()
      )
    }

    var candidateRows = Set(exactRows)
    candidateRows.formUnion(plausible.map(\.rows))

    var scored = candidateRows.map {
      score(
        preceding: preceding.image,
        following: following.image,
        overlapRows: $0
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

    if let competing = acceptable.dropFirst().first,
      overlapsAreAmbiguous(best, competing)
    {
      throw ReconstructionFailure.ambiguousOverlap(
        preceding: preceding.id,
        following: following.id,
        candidateRows: [best.overlapRows, competing.overlapRows].sorted()
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
      guard !overflow, contribution > 0 else {
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

  func sampledError(
    preceding: RasterImage,
    following: RasterImage,
    overlapRows: Int
  ) -> Double {
    let rows = sampleIndices(count: overlapRows, maximum: settings.sampledRows)
    let columns = sampleIndices(count: preceding.width, maximum: settings.sampledColumns)
    let precedingStartRow = preceding.height - overlapRows
    var difference: UInt64 = 0

    for row in rows {
      for column in columns {
        let precedingOffset = preceding.byteOffset(
          x: column,
          y: precedingStartRow + row
        )
        let followingOffset = following.byteOffset(x: column, y: row)
        for channel in 0..<RasterImage.channelsPerPixel {
          difference += UInt64(
            abs(
              Int(preceding.pixels[precedingOffset + channel])
                - Int(following.pixels[followingOffset + channel])
            )
          )
        }
      }
    }

    let denominator = Double(rows.count)
      * Double(columns.count)
      * Double(RasterImage.channelsPerPixel)
      * 255
    return Double(difference) / denominator
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

  func overlapsAreAmbiguous(
    _ best: OverlapCandidate,
    _ competing: OverlapCandidate
  ) -> Bool {
    abs(
      best.normalizedMeanAbsoluteError
        - competing.normalizedMeanAbsoluteError
    ) <= settings.ambiguityTolerance
      && abs(best.changedPixelFraction - competing.changedPixelFraction)
        <= settings.ambiguityTolerance
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
