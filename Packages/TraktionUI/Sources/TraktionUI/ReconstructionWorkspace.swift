#if canImport(SwiftUI)
  import SwiftUI

  public struct ReconstructionWorkspace: View {
    public init() {}
    public var body: some View {
      NavigationSplitView {
        ContentUnavailableView(
          "No Captures", systemImage: "photo.on.rectangle.angled",
          description: Text("Import 2–10 overlapping PNG screenshots to begin.")
        )
        .navigationTitle("Captures")
      } detail: {
        ContentUnavailableView(
          "Ready to Reconstruct", systemImage: "rectangle.3.group",
          description: Text("Source captures remain unchanged.")
        )
        .navigationTitle("TRAKTION")
      }
    }
  }
#else
  public enum ReconstructionWorkspaceAvailability { public static let requiresSwiftUI = true }
#endif
