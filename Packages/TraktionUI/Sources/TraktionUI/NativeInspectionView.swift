#if canImport(SwiftUI)
  import SwiftUI
  import TraktionDomain

  @MainActor
  struct NativeInspectionView: View {
    let model: NativeInspectionModel
    @Environment(\.displayScale) private var displayScale

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let result = model.result {
              Text("\(result.image.width) × \(result.image.height) pixels")
                .font(.headline)
                .accessibilityIdentifier("inspection.dimensions")
              regionPicker
              if let joint = model.joint { jointEvidence(joint) }
              if model.joint != nil { seamControls; sourcePicker }
              historyControls
              Text("Pixels: \(model.sourceName)")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("inspection.source")
              canvas
              viewportDetails
              zoomControls
              panControls
              Text("1:1 shows one source pixel per display pixel. Drag the image to pan, or use the direction buttons. Inspect the original pixels, or deliberately adjust a selected joint inside its proven overlap.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("inspection.scroll")
        .navigationTitle("Pixel inspection")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { model.close() }
              .accessibilityIdentifier("inspection.done")
          }
        }
      }
      .onDisappear { model.close() }
      #if os(macOS)
        .frame(minWidth: 420, minHeight: 500)
      #endif
    }

    private var regionPicker: some View {
      Menu {
        Button("Entire result") { model.selectJoint(nil) }
          .accessibilityIdentifier("inspection.region.result")
        if let result = model.result {
          ForEach(Array(result.plan.joints.enumerated()), id: \.offset) { index, _ in
            Button("Joint \(index + 1)") { model.selectJoint(index) }
              .accessibilityIdentifier("inspection.region.joint.\(index)")
          }
        }
      } label: {
        Label(model.jointIndex.map { "Joint \($0 + 1)" } ?? "Entire result", systemImage: "square.stack")
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityLabel("Region")
      .accessibilityValue(model.jointIndex.map { "Joint \($0 + 1)" } ?? "Entire result")
      .disabled(model.editing.draft != nil || model.editing.isRendering)
      .accessibilityIdentifier("inspection.region")
    }

    private var sourcePicker: some View {
      Menu {
        Button("Result") { model.selectSource(.result) }
          .accessibilityIdentifier("inspection.source.result")
        Button("First original") { model.selectSource(.preceding) }
          .accessibilityIdentifier("inspection.source.preceding")
        Button("Second original") { model.selectSource(.following) }
          .accessibilityIdentifier("inspection.source.following")
      } label: {
        Label("Choose pixels to inspect", systemImage: "photo.on.rectangle")
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityIdentifier("inspection.source.choose")
    }

    private func jointEvidence(_ joint: InspectionJoint) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("First: \(joint.preceding.sourceName)\nSecond: \(joint.following.sourceName)")
          .accessibilityIdentifier("inspection.joint.names")
        Text("Capture \(joint.precedingPosition) → capture \(joint.followingPosition)")
          .font(.caption)
          .accessibilityIdentifier("inspection.joint.positions")
        Text("Confidence: \(joint.diagnosis.confidence.rawValue.capitalized). Overlap: \(joint.diagnosis.overlapRows) rows.")
          .accessibilityIdentifier("inspection.joint.confidence")
        if let index = model.jointIndex, let automatic = model.result?.plan.joints[index] {
          Text("Automatic seam: overlap row \(automatic.seamRowInOverlap). Registration confidence is unchanged by manual selection.")
            .font(.caption)
            .accessibilityIdentifier("inspection.joint.automaticSeam")
        }
        Text("Seam boundary at output row \(joint.diagnosis.outputSeamRow); overlap row \(joint.diagnosis.seamRowInOverlap). First original row \(joint.precedingSeamRow); second original row \(joint.followingSeamRow).")
          .accessibilityIdentifier("inspection.joint.seam")
        Text("Zero-based coordinates. The second capture supplies the seam row and rows below it until the next joint. Select an original to see its own unchanged pixels around this boundary.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }

    private var seamControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        if let draft = model.editing.draft {
          Text("Draft seam: overlap row \(draft.seamRowInOverlap)")
            .accessibilityIdentifier("inspection.edit.draft")
          if let range = model.editing.allowedRange {
            Text("Allowed rows: \(range.lowerBound)…\(range.upperBound). The second original supplies the boundary row.")
              .font(.caption)
            VStack(alignment: .leading, spacing: 12) {
              nudgeButton("Move seam up 1 pixel", delta: -1, id: "up", range: range)
              nudgeButton("Move seam down 1 pixel", delta: 1, id: "down", range: range)
              nudgeButton("Move seam up 10 pixels", delta: -10, id: "up10", range: range)
              nudgeButton("Move seam down 10 pixels", delta: 10, id: "down10", range: range)
            }
          }
          Button("Apply seam adjustment") { model.editing.apply() }
            .disabled(model.editing.isRendering || model.isRendering)
            .accessibilityIdentifier("inspection.edit.apply")
          Button("Cancel seam adjustment") { model.editing.cancelDraft() }
            .accessibilityIdentifier("inspection.edit.cancel")
        } else {
          Button("Adjust this seam") {
            if let index = model.jointIndex { model.editing.begin(joint: index) }
          }
          .disabled(!model.editing.isAdmitted || model.editing.document == nil || model.editing.isRendering)
          .accessibilityIdentifier("inspection.edit.begin")
          if !model.editing.isAdmitted {
            Text("Seam editing needs more workspace memory. Pixel inspection remains available.")
              .font(.caption)
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }

    private func nudgeButton(_ title: String, delta: Int, id: String, range: ClosedRange<Int>) -> some View {
      Button(title) { model.editing.nudge(delta) }
        .disabled(model.editing.isRendering || !range.contains((model.editing.draft?.seamRowInOverlap ?? 0) + delta))
        .accessibilityIdentifier("inspection.edit.\(id)")
    }

    private var historyControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(model.editing.draft != nil ? "Draft preview — not applied" : (model.editing.isModified ? "Modified seams" : "Automatic seams"))
          .accessibilityIdentifier("inspection.edit.state")
        Button("Undo seam adjustment") { model.editing.undo() }
          .disabled(!model.editing.canUndo)
          .accessibilityIdentifier("inspection.edit.undo")
        Button("Redo seam adjustment") { model.editing.redo() }
          .disabled(!model.editing.canRedo)
          .accessibilityIdentifier("inspection.edit.redo")
        if model.editing.isRendering { ProgressView("Updating adjusted preview") }
        if let failure = model.editing.failure {
          Text(failure)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("inspection.edit.failure")
        }
      }
    }

    private var canvas: some View {
      GeometryReader { geometry in
        let scale = max(1, displayScale)
        // Integer display dimensions preserve physical-pixel 1:1 at every scale.
        let width = max(1, min(1_024, Int((min(320, geometry.size.width) * scale).rounded(.down))))
        let height = max(1, min(1_024, Int((240 * scale).rounded(.down))))
        ZStack(alignment: .topLeading) {
          Color.secondary.opacity(0.12)
          if let frame = model.frame {
            Image(frame.image, scale: scale, orientation: .up, label: Text("Inspected pixels"))
              .resizable()
              .interpolation(.none)
              .accessibilityIdentifier("inspection.canvas")
          } else if let failure = model.failure {
            Text(failure).padding()
              .accessibilityIdentifier("inspection.failure")
          } else {
            ProgressView("Loading pixels")
          }
        }
        .frame(width: Double(width) / scale, height: Double(height) / scale)
        .clipped()
        .contentShape(Rectangle())
        .gesture(DragGesture().onEnded { value in
          model.pan(dx: -value.translation.width * scale, dy: -value.translation.height * scale)
        })
        .onChange(of: width, initial: true) { _, _ in model.resize(width: width, height: height) }
        .onChange(of: height) { _, _ in model.resize(width: width, height: height) }
      }
      .frame(height: min(240, 1_024 / max(1, displayScale)))
    }

    private var viewportDetails: some View {
      VStack(alignment: .leading, spacing: 4) {
        if let viewport = model.viewport {
          Text("Zoom: \(viewport.zoomPercentText)\(viewport.zoom == 1 ? " (1:1)" : "")")
            .accessibilityIdentifier("inspection.zoom")
          Text("\(model.sourceWidth) × \(model.sourceHeight) source pixels. View starts at x \(Int(viewport.x)), y \(Int(viewport.y)).")
            .accessibilityIdentifier("inspection.coordinates")
        }
      }
      .font(.callout)
      .fixedSize(horizontal: false, vertical: true)
    }

    private var zoomControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        Button("1:1 pixels") { model.setZoom(1) }
          .accessibilityIdentifier("inspection.oneToOne")
        Button("Fit entire image") { model.fit() }
          .accessibilityIdentifier("inspection.fit")
        HStack(spacing: 20) {
          Button { model.setZoom((model.viewport?.zoom ?? 1) / 2) } label: {
            Image(systemName: "minus.magnifyingglass").frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel("Zoom out")
          .accessibilityIdentifier("inspection.zoomOut")
          Button { model.setZoom((model.viewport?.zoom ?? 1) * 2) } label: {
            Image(systemName: "plus.magnifyingglass").frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel("Zoom in")
          .accessibilityIdentifier("inspection.zoomIn")
        }
      }
    }

    private var panControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          panButton("left", symbol: "arrow.left", dx: -1, dy: 0)
          panButton("right", symbol: "arrow.right", dx: 1, dy: 0)
          panButton("up", symbol: "arrow.up", dx: 0, dy: -1)
          panButton("down", symbol: "arrow.down", dx: 0, dy: 1)
        }
        Button("Go to top") { model.edge(bottom: false) }
          .accessibilityIdentifier("inspection.top")
        Button("Go to bottom") { model.edge(bottom: true) }
          .accessibilityIdentifier("inspection.bottom")
      }
    }

    private func panButton(_ direction: String, symbol: String, dx: Double, dy: Double) -> some View {
      Button {
        guard let viewport = model.viewport else { return }
        model.pan(dx: dx * Double(viewport.width) * 0.8, dy: dy * Double(viewport.height) * 0.8)
      } label: {
        Image(systemName: symbol).frame(minWidth: 44, minHeight: 44)
      }
      .accessibilityLabel("Pan \(direction)")
      .accessibilityIdentifier("inspection.pan.\(direction)")
    }
  }
#endif
