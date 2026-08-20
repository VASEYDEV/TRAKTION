#if canImport(SwiftUI)
  import SwiftUI
  import TraktionUI

  @main
  struct TRAKTIONApp: App {
    var body: some Scene { WindowGroup { ReconstructionWorkspace() } }
  }
#else
  @main enum TRAKTIONApp {
    static func main() { print("TRAKTION requires SwiftUI and an Apple platform.") }
  }
#endif
