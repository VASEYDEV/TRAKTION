import TraktionDomain

/// Immutable source evidence plus small plan snapshots. History never owns bitmap copies.
public struct SeamEditingDocument: Sendable {
  public let originalPlan: ReconstructionPlan
  public private(set) var plan: ReconstructionPlan
  private var undoPlans: [ReconstructionPlan] = []
  private var redoPlans: [ReconstructionPlan] = []
  public var canUndo: Bool { !undoPlans.isEmpty }
  public var canRedo: Bool { !redoPlans.isEmpty }
  public var isModified: Bool { plan != originalPlan }

  public init(plan: ReconstructionPlan, captures: [CaptureAsset]) throws {
    _ = try PlannedRasterRenderer(plan: plan, captures: captures)
    originalPlan = plan
    self.plan = plan
  }

  /// Restores final seams directly, preserving evidence without inventing replay order.
  /// Undo/redo history intentionally starts empty for the reopened session.
  public init(originalPlan: ReconstructionPlan, committedPlan: ReconstructionPlan,
    captures: [CaptureAsset]) throws {
    _ = try PlannedRasterRenderer(plan: originalPlan, captures: captures)
    _ = try PlannedRasterRenderer(plan: committedPlan, captures: captures)
    guard originalPlan.axis == committedPlan.axis,
      originalPlan.outputWidth == committedPlan.outputWidth,
      originalPlan.outputHeight == committedPlan.outputHeight,
      originalPlan.placements == committedPlan.placements,
      originalPlan.joints.count == committedPlan.joints.count else {
      throw SeamEditingFailure.invalidPlan
    }
    for (original, committed) in zip(originalPlan.joints, committedPlan.joints) {
      guard original.precedingCaptureID == committed.precedingCaptureID,
        original.followingCaptureID == committed.followingCaptureID,
        original.overlapRows == committed.overlapRows,
        original.normalizedMeanAbsoluteError == committed.normalizedMeanAbsoluteError,
        original.changedPixelFraction == committed.changedPixelFraction,
        original.confidence == committed.confidence else { throw SeamEditingFailure.invalidPlan }
    }
    self.originalPlan = originalPlan
    self.plan = committedPlan
  }

  public func allowedRange(for index: Int) throws -> ClosedRange<Int> {
    guard plan.joints.indices.contains(index) else { throw SeamEditingFailure.invalidJoint }
    let joint = plan.joints[index]
    guard joint.confidence == .exact || joint.confidence == .strong else {
      throw SeamEditingFailure.unsupportedEvidence
    }
    let origin = plan.placements[index + 1].originY
    let previous = index == 0 ? 0 : plan.joints[index - 1].outputSeamRow
    let next = index == plan.joints.count - 1 ? plan.outputHeight : plan.joints[index + 1].outputSeamRow
    // Strict ordering keeps every capture represented; cutting is a separate feature.
    let lower = max(0, previous + 1 - origin)
    let upper = min(joint.overlapRows, next - 1 - origin)
    guard lower <= upper else { throw SeamEditingFailure.crossingSeams }
    return lower...upper
  }

  public func preview(_ edit: SeamAdjustment) throws -> ReconstructionPlan {
    guard let index = plan.joints.firstIndex(where: {
      $0.precedingCaptureID == edit.precedingCaptureID && $0.followingCaptureID == edit.followingCaptureID
    }) else { throw SeamEditingFailure.invalidJoint }
    let old = plan.joints[index]
    guard (0...old.overlapRows).contains(edit.seamRowInOverlap) else {
      throw SeamEditingFailure.outsideProvenOverlap
    }
    guard try allowedRange(for: index).contains(edit.seamRowInOverlap) else {
      throw SeamEditingFailure.crossingSeams
    }
    var joints = plan.joints
    joints[index] = JointDiagnosis(precedingCaptureID: old.precedingCaptureID,
      followingCaptureID: old.followingCaptureID, overlapRows: old.overlapRows,
      seamRowInOverlap: edit.seamRowInOverlap,
      outputSeamRow: plan.placements[index + 1].originY + edit.seamRowInOverlap,
      normalizedMeanAbsoluteError: old.normalizedMeanAbsoluteError,
      changedPixelFraction: old.changedPixelFraction, confidence: old.confidence)
    return ReconstructionPlan(axis: plan.axis, outputWidth: plan.outputWidth,
      outputHeight: plan.outputHeight, placements: plan.placements, joints: joints)
  }

  public mutating func apply(_ edit: SeamAdjustment) throws {
    let next = try preview(edit)
    guard next != plan else { return }
    undoPlans.append(plan)
    plan = next
    redoPlans = []
  }

  public mutating func undo() {
    guard let previous = undoPlans.popLast() else { return }
    redoPlans.append(plan); plan = previous
  }

  public mutating func redo() {
    guard let next = redoPlans.popLast() else { return }
    undoPlans.append(plan); plan = next
  }
}

/// A validated, lazy composition. Capture arrays share immutable original storage.
/// No full-resolution composite is allocated for manual editing.
public struct PlannedRasterRenderer: Sendable {
  public let plan: ReconstructionPlan
  private let orderedCaptures: [CaptureAsset]
  public static let maximumSamplePixels = 1_048_576
  public static let maximumSampleEdge = 4_096

  public init(plan: ReconstructionPlan, captures: [CaptureAsset]) throws {
    guard plan.axis == .vertical, (2...10).contains(captures.count),
      plan.placements.count == captures.count, plan.joints.count == captures.count - 1,
      plan.outputWidth > 0, plan.outputHeight > 0,
      Set(captures.map(\.id)).count == captures.count,
      Set(plan.placements.map(\.captureID)).count == captures.count,
      plan.placements.first?.originY == 0
    else { throw SeamEditingFailure.invalidPlan }
    var ordered: [CaptureAsset] = []
    for placement in plan.placements {
      guard let capture = captures.first(where: { $0.id == placement.captureID }),
        placement.width == plan.outputWidth, capture.image.width == placement.width,
        capture.image.height == placement.height, placement.originY >= 0
      else { throw SeamEditingFailure.invalidPlan }
      let (end, overflow) = placement.originY.addingReportingOverflow(placement.height)
      guard !overflow, end <= plan.outputHeight else { throw SeamEditingFailure.invalidPlan }
      ordered.append(capture)
    }
    guard let last = plan.placements.last,
      last.originY + last.height == plan.outputHeight else { throw SeamEditingFailure.invalidPlan }
    for index in plan.joints.indices {
      let joint = plan.joints[index]
      let first = plan.placements[index]
      let second = plan.placements[index + 1]
      guard joint.precedingCaptureID == first.captureID, joint.followingCaptureID == second.captureID,
        joint.overlapRows > 0, joint.overlapRows <= min(first.height, second.height),
        (0...joint.overlapRows).contains(joint.seamRowInOverlap),
        second.originY >= first.originY,
        second.originY - first.originY == first.height - joint.overlapRows,
        joint.outputSeamRow >= second.originY,
        joint.outputSeamRow - second.originY == joint.seamRowInOverlap,
        joint.normalizedMeanAbsoluteError.isFinite,
        (0...1).contains(joint.normalizedMeanAbsoluteError),
        joint.changedPixelFraction.isFinite, (0...1).contains(joint.changedPixelFraction)
      else { throw SeamEditingFailure.invalidPlan }
      guard joint.confidence == .exact || joint.confidence == .strong else {
        throw SeamEditingFailure.unsupportedEvidence
      }
    }
    for index in ordered.indices {
      let start = index == 0 ? 0 : plan.joints[index - 1].outputSeamRow
      let end = index == ordered.count - 1 ? plan.outputHeight : plan.joints[index].outputSeamRow
      let origin = plan.placements[index].originY
      guard start < end, start >= origin, end - origin <= ordered[index].image.height else {
        throw SeamEditingFailure.crossingSeams
      }
    }
    self.plan = plan
    orderedCaptures = ordered
  }

  /// Exact original pixels, with no scaling or full-composite allocation.
  /// The caller admits its overall working set before requesting rows.
  public func rgbaRow(_ row: Int, isCancelled: @Sendable () -> Bool) throws -> [UInt8] {
    guard row >= 0, row < plan.outputHeight else { throw SeamEditingFailure.invalidRegion }
    let (bytes, overflow) = plan.outputWidth.multipliedReportingOverflow(by: 4)
    guard !overflow, bytes <= 1_048_576 else { throw SeamEditingFailure.invalidRegion }
    guard !isCancelled() else { throw SeamEditingFailure.cancelled }
    let index = plan.joints.prefix { row >= $0.outputSeamRow }.count
    let source = orderedCaptures[index].image
    let start = (row - plan.placements[index].originY) * bytes
    let pixels = Array(source.pixels[start..<start + bytes])
    guard !isCancelled() else { throw SeamEditingFailure.cancelled }
    return pixels
  }

  public func renderPreview(width: Int, height: Int, isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    guard (1...Self.maximumSampleEdge).contains(width), (1...Self.maximumSampleEdge).contains(height),
      width * height <= Self.maximumSamplePixels else { throw SeamEditingFailure.invalidRegion }
    let (_, xOverflow) = (width - 1).multipliedReportingOverflow(by: plan.outputWidth)
    let (_, yOverflow) = (height - 1).multipliedReportingOverflow(by: plan.outputHeight)
    guard !xOverflow, !yOverflow else { throw SeamEditingFailure.invalidRegion }
    return try sample(width: width, height: height, x: { Double($0 * plan.outputWidth / width) },
      y: { Double($0 * plan.outputHeight / height) }, isCancelled: isCancelled)
  }

  public func render(_ region: RasterSamplingRegion, isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    guard (1...Self.maximumSampleEdge).contains(region.width),
      (1...Self.maximumSampleEdge).contains(region.height),
      region.width * region.height <= Self.maximumSamplePixels,
      region.x.isFinite, region.y.isFinite, region.x >= 0, region.y >= 0,
      region.x < Double(plan.outputWidth), region.y < Double(plan.outputHeight),
      region.scale.isFinite, region.scale > 0, region.scale <= 16
    else { throw SeamEditingFailure.invalidRegion }
    return try sample(width: region.width, height: region.height,
      x: { region.x + Double($0) / region.scale }, y: { region.y + Double($0) / region.scale },
      isCancelled: isCancelled)
  }

  private func sample(width: Int, height: Int, x: (Int) -> Double, y: (Int) -> Double,
    isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    guard !isCancelled() else { throw SeamEditingFailure.cancelled }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var captureIndex = 0
    for row in 0..<height {
      guard !isCancelled() else { throw SeamEditingFailure.cancelled }
      let outputY = y(row)
      guard outputY < Double(plan.outputHeight) else { continue }
      let y = Int(outputY.rounded(.down))
      while captureIndex < plan.joints.count && y >= plan.joints[captureIndex].outputSeamRow {
        captureIndex += 1
      }
      let source = orderedCaptures[captureIndex].image
      let sourceY = y - plan.placements[captureIndex].originY
      for column in 0..<width {
        let outputX = x(column)
        guard outputX < Double(plan.outputWidth) else { continue }
        let offset = (sourceY * source.width + Int(outputX.rounded(.down))) * 4
        let destination = (row * width + column) * 4
        for channel in 0..<4 { pixels[destination + channel] = source.pixels[offset + channel] }
      }
    }
    guard !isCancelled() else { throw SeamEditingFailure.cancelled }
    return try RasterImage(width: width, height: height, pixels: pixels)
  }
}
