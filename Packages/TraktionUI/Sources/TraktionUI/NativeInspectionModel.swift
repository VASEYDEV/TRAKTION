import Dispatch
import Foundation
import Observation
import TraktionDomain

@MainActor
@Observable
final class NativeInspectionModel {
  enum Source: String, CaseIterable { case result, preceding, following }

  private(set) var isOpen = false
  private(set) var isRendering = false
  private(set) var frame: InspectionFrame?
  private(set) var failure: String?
  private(set) var jointIndex: Int?
  private(set) var joint: InspectionJoint?
  private(set) var source: Source = .result
  private(set) var viewport: InspectionViewport?
  private(set) var result: ReconstructionResult?
  private(set) var sourceName = "Result"
  private(set) var sourceWidth = 0
  private(set) var sourceHeight = 0

  @ObservationIgnored private var captures: [CaptureAsset] = []
  @ObservationIgnored private var sourceRaster: RasterImage?
  @ObservationIgnored private let renderer: any InspectionRendering
  @ObservationIgnored private let queue = DispatchQueue(label: "dev.vasey.traktion.inspection", qos: .userInitiated)
  @ObservationIgnored private var generation = UUID()
  @ObservationIgnored private var activeToken: NativeWorkspaceCancellation?
  @ObservationIgnored private var pending: InspectionViewport?

  init(renderer: any InspectionRendering = InspectionRasterRenderer()) { self.renderer = renderer }

  func open(result: ReconstructionResult, captures: [CaptureAsset], retainedBytes: Int, budget: Int) throws {
    guard !isRendering, retainedBytes >= 0,
      budget >= InspectionViewport.reservedBytes,
      retainedBytes <= budget - InspectionViewport.reservedBytes
    else { throw InspectionFailure.resourceLimit }
    close()
    self.result = result
    self.captures = captures
    isOpen = true
    selectJoint(nil)
  }

  /// A draining job keeps its slot until completion, including after dismissal/reset.
  /// The workspace blocks replacement work while this is true.
  func close() {
    generation = UUID()
    activeToken?.cancel()
    pending = nil
    frame = nil
    viewport = nil
    sourceRaster = nil
    captures = []
    result = nil
    joint = nil
    jointIndex = nil
    source = .result
    sourceName = "Result"
    sourceWidth = 0
    sourceHeight = 0
    failure = nil
    isOpen = false
  }

  func selectJoint(_ index: Int?) {
    guard isOpen, let result else { return }
    do {
      if let index {
        guard result.plan.joints.indices.contains(index) else { throw InspectionFailure.invalidJoint }
        joint = try InspectionJoint(result.plan.joints[index], result: result, captures: captures)
      } else { joint = nil }
      jointIndex = index
      selectSource(.result)
    } catch {
      invalidateFrame()
      failure = "This joint could not be mapped to the original captures."
    }
  }

  func selectSource(_ source: Source) {
    guard isOpen, let result else { return }
    let image: RasterImage
    let name: String
    let seam: Int?
    switch source {
    case .result:
      image = result.image
      name = "Result"
      seam = joint?.diagnosis.outputSeamRow
    case .preceding:
      guard let joint else { return }
      image = joint.preceding.image
      name = joint.preceding.sourceName
      seam = joint.precedingSeamRow
    case .following:
      guard let joint else { return }
      image = joint.following.image
      name = joint.following.sourceName
      seam = joint.followingSeamRow
    }
    invalidateFrame()
    self.source = source
    sourceName = name
    sourceRaster = image
    sourceWidth = image.width
    sourceHeight = image.height
    if let viewport {
      let zoom = seam == nil ? fitZoom(width: viewport.width, height: viewport.height) : 1
      update(width: viewport.width, height: viewport.height, x: 0,
        y: Double(seam ?? 0) - Double(viewport.height) / (2 * zoom), zoom: zoom)
    }
  }

  func resize(width: Int, height: Int) {
    guard isOpen, width > 0, height > 0 else { return }
    let w = min(width, InspectionViewport.maximumEdge)
    let h = min(height, InspectionViewport.maximumEdge)
    if viewport?.width == w && viewport?.height == h { return }
    update(width: w, height: h, x: viewport?.x ?? 0, y: viewport?.y ?? 0,
      zoom: viewport?.zoom ?? fitZoom(width: w, height: h))
  }

  func fit() {
    guard let viewport else { return }
    update(width: viewport.width, height: viewport.height, x: 0, y: 0,
      zoom: fitZoom(width: viewport.width, height: viewport.height))
  }

  func setZoom(_ zoom: Double) {
    guard let viewport, zoom.isFinite else { return }
    let zoom = min(16, max(fitZoom(width: viewport.width, height: viewport.height), zoom))
    let centerX = viewport.x + min(Double(sourceWidth) - viewport.x, Double(viewport.width) / viewport.zoom) / 2
    let centerY = viewport.y + min(Double(sourceHeight) - viewport.y, Double(viewport.height) / viewport.zoom) / 2
    update(width: viewport.width, height: viewport.height,
      x: centerX - Double(viewport.width) / (2 * zoom),
      y: centerY - Double(viewport.height) / (2 * zoom), zoom: zoom)
  }

  /// Delta is in display pixels. Buttons and gestures use the same coordinate path.
  func pan(dx: Double, dy: Double) {
    guard let viewport, dx.isFinite, dy.isFinite else { return }
    update(width: viewport.width, height: viewport.height,
      x: viewport.x + dx / viewport.zoom, y: viewport.y + dy / viewport.zoom, zoom: viewport.zoom)
  }

  func edge(bottom: Bool) {
    guard let viewport else { return }
    update(width: viewport.width, height: viewport.height, x: viewport.x,
      y: bottom ? Double(sourceHeight) : 0, zoom: viewport.zoom)
  }

  private func fitZoom(width: Int, height: Int) -> Double {
    min(1, Double(width) / Double(max(1, sourceWidth)),
      Double(height) / Double(max(1, sourceHeight)))
  }

  private func update(width: Int, height: Int, x: Double, y: Double, zoom: Double) {
    guard isOpen, sourceRaster != nil else { return }
    // Whole source-pixel origins make 1:1 and integer magnifications exact.
    func lastOrigin(source: Int, visible: Int) -> Double {
      guard Double(visible) / zoom < Double(source) else { return 0 }
      // Align the final sampled coordinate, including fractional magnifications.
      return Double(source - 1) - (Double(visible - 1) / zoom).rounded(.down)
    }
    let x = max(0, min(x, lastOrigin(source: sourceWidth, visible: width))).rounded(.down)
    let y = max(0, min(y, lastOrigin(source: sourceHeight, visible: height))).rounded(.down)
    guard let next = try? InspectionViewport(width: width, height: height, x: x, y: y, zoom: zoom) else { return }
    viewport = next
    frame = nil
    failure = nil
    generation = UUID()
    activeToken?.cancel()
    pending = next
    startPending()
  }

  private func invalidateFrame() {
    generation = UUID()
    activeToken?.cancel()
    pending = nil
    frame = nil
    failure = nil
  }

  private func startPending() {
    guard !isRendering, isOpen, let next = pending, let image = sourceRaster else { return }
    pending = nil
    isRendering = true
    let id = generation
    let token = NativeWorkspaceCancellation()
    activeToken = token
    let renderer = self.renderer
    queue.async { [weak self] in
      let outcome: Result<InspectionFrame, Error> = Result {
        try renderer.render(image, viewport: next, isCancelled: { token.isCancelled })
      }
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isRendering = false
        self.activeToken = nil
        if self.isOpen, self.generation == id {
          switch outcome {
          case .success(let frame): self.frame = frame
          case .failure: self.failure = "The pixel view could not be rendered. Try Fit or reopen inspection."
          }
        }
        self.startPending()
      }
    }
  }
}
